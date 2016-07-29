import Foundation
import CoreData

import Faro

class CoreDataEntity: FaroCoreDataParent, EnvironmentConfigurable, CoreDataParsable {

	/**
	You should override this method. Swift does not inherit the initializers from its superclass.
	*/
	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}

	required init(json: AnyObject, managedObjectContext: NSManagedObjectContext? = CoreDataEntity.managedObjectContext()) throws {
		let entity = NSEntityDescription.entityForName("CoreDataEntity", inManagedObjectContext: managedObjectContext!)
		super.init(entity: entity!, insertIntoManagedObjectContext: managedObjectContext)
		try self.map(json)
	}


	func toDictionary()-> NSDictionary? {
		return ["uniqueValue": uniqueValue!, "username": username!]
	}

	func map(json: AnyObject) throws {
		if let uniqueValue = json["uniqueValue"] as? String {
			self.uniqueValue = uniqueValue
		}

		if let username = json["username"] as? String {
			self.username = username
		}
	}

	override class func rootKey() -> String? {
		return "results"
	}

	static func lookupExistingObjectFromJSON(json: AnyObject, managedObjectContext: NSManagedObjectContext?) throws -> Self? {

		guard let managedObjectContext = managedObjectContext else  {
			return nil
		}

		return autocast(try fetchInCoreDataFromJSON(json, managedObjectContext: managedObjectContext, entityName: "CoreDataEntity", uniqueValueKey: "uniqueValue"))
	}

	class func managedObjectContext() -> NSManagedObjectContext? {
		return CoreDataController.sharedInstance.managedObjectContext
	}

	//MARK: - EnvironmentConfigurable

	class func environment() -> protocol<Environment, Mockable> {
		return EnvironmentParse<CoreDataEntity>()
	}

	static func contextPath() -> String {
		return "CoreDataEntity"
	}

}

