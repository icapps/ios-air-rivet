import Faro

class ExampleBar: Bar {

    init() {
        super.init(service: Service(configuration: Configuration(baseURL: "http://jsonplaceholder.typicode.com")))
    }

    override func perform<M: Mappable>(call: Call, result: (Result<M>) -> ()) {
        super.perform(call, result: result)
    }

}