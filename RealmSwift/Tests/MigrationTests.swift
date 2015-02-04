////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import XCTest
import RealmSwift
import Realm
import Realm.Private

private func realmWithCustomSchema(path: String, schema :RLMSchema) -> RLMRealm {
    return RLMRealm(path: path, key: nil, readOnly: false, inMemory: false, dynamic: true, schema: schema, error: nil)!
}

private func realmWithSingleClass(path: String, objectSchema: RLMObjectSchema) -> RLMRealm {
    let schema = RLMSchema()
    schema.objectSchema = [objectSchema]
    return realmWithCustomSchema(path, schema)
}

private func realmWithSingleClassProperties(path: String, className: String, properties: [AnyObject]) -> RLMRealm {
    let objectSchema = RLMObjectSchema(className: className, objectClass: MigrationObject.self, properties: properties)
    return realmWithSingleClass(path, objectSchema)
}

class MigrationTests: TestCase {

    // MARK Utility methods

    // create realm at path and test version is 0
    private func createAndTestRealmAtPath(realmPath: String) {
        autoreleasepool { () -> () in
            Realm(path: realmPath)
            return
        }
        XCTAssertEqual(UInt(0), schemaVersionAtPath(realmPath)!, "Initial version should be 0")
    }

    // migrate realm at path and ensure migration
    private func migrateAndTestRealmAtPath(realmPath: String, shouldRun: Bool = true, block: MigrationBlock? = nil) {
        var didRun = false
        setSchemaVersion(1, realmPath, { migration, oldSchemaVersion in
            if let block = block {
                block(migration: migration, oldSchemaVersion: oldSchemaVersion)
            }
            didRun = true
            return
        })

        // accessing Realm should automigrate
        Realm(path: realmPath)
        XCTAssertEqual(didRun, shouldRun)
    }

    // migrate default realm and ensure migration
    private func migrateAndTestDefaultRealm(shouldRun: Bool = true, block: MigrationBlock? = nil) {
        var didRun = false
        setDefaultRealmSchemaVersion(1, { migration, oldSchemaVersion in
            if let block = block {
                block(migration: migration, oldSchemaVersion: oldSchemaVersion)
            }
            didRun = true
            return
        })

        // accessing Realm should automigrate
        defaultRealm()
        XCTAssertEqual(didRun, shouldRun)
    }


    // MARK Test cases

    func testSetDefaultRealmSchemaVersion() {
        createAndTestRealmAtPath(defaultRealmPath())
        migrateAndTestDefaultRealm()

        XCTAssertEqual(UInt(1), schemaVersionAtPath(defaultRealmPath())!)
    }

    func testSetSchemaVersion() {
        createAndTestRealmAtPath(testRealmPath())
        migrateAndTestRealmAtPath(testRealmPath())

        XCTAssertEqual(UInt(1), schemaVersionAtPath(testRealmPath())!)
    }

    func testSchemaVersionAtPath() {
        var error : NSError? = nil
        XCTAssertNil(schemaVersionAtPath(defaultRealmPath(), error: &error), "Version should be nil before Realm creation")
        XCTAssertNotNil(error, "Error should be set")

        defaultRealm()
        XCTAssertEqual(UInt(0), schemaVersionAtPath(defaultRealmPath())!, "Initial version should be 0")
    }

    func testMigrateRealm() {
        createAndTestRealmAtPath(testRealmPath())

        var migrationCount = 0
        setSchemaVersion(1, testRealmPath(), { migration, oldSchemaVersion in
            migrationCount++
            return
        })

        // manually migrate
        migrateRealm(testRealmPath())
        XCTAssertEqual(1, migrationCount)

        // calling again should be no-op
        migrateRealm(testRealmPath())
        XCTAssertEqual(1, migrationCount)
    }

    func testMigrationProperties() {
        let prop = RLMProperty(name: "stringCol", type: RLMPropertyType.Int, objectClassName: nil, indexed: false)
        autoreleasepool { () -> () in
            realmWithSingleClassProperties(defaultRealmPath(), "SwiftStringObject", [prop])
            return
        }

        migrateAndTestDefaultRealm(block: { migration, oldSchemaVersion in
            XCTAssertEqual(migration.oldSchema["SwiftStringObject"]!["stringCol"]!.type, PropertyType.Int)
            XCTAssertEqual(migration.newSchema["SwiftStringObject"]!["stringCol"]!.type, PropertyType.String)
        })
    }
}

