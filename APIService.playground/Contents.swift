import Foundation
import PlaygroundSupport

enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
    case trace = "TRACE"
    case connect = "CONNECT"
}

struct HTTPHeader {
    let field: String
    let value: String
}

class APIRequest {
    let method: HTTPMethod
    let path: String
    var queryItems: [URLQueryItem]?
    var headers: [HTTPHeader]?
    var body: Data?
    
    init(method: HTTPMethod, path: String) {
        self.method = method
        self.path = path
    }
    
    init(method: HTTPMethod, path: String, headers: [HTTPHeader], body: Data?) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
    
    init<Body: Encodable>(method: HTTPMethod, path: String, body: Body) throws {
        self.method = method
        self.path = path
        self.body = try JSONEncoder().encode(body)
    }
}

struct APIResponse<Body> {
    let statusCode: Int
    let body: Body
}

extension APIResponse where Body == Data? {
    func decode<BodyType: Decodable>(to type: BodyType.Type) throws -> APIResponse<BodyType> {
        guard let data = body else {
            throw APIError.decodingFailure
        }
        let jsonDecoder = JSONDecoder()
        let decodedJSON = try jsonDecoder.decode(BodyType.self, from: data)
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return APIResponse<BodyType>(statusCode: self.statusCode,
                                     body: decodedJSON)
    }
}

enum APIError: Error {
    case invalidURL
    case requestFailed
    case decodingFailure
}

enum APIResult<Body> {
    case success(APIResponse<Body>)
    case failure(APIError)
}

struct APIClient {
    typealias APIClientCompletion = (APIResult<Data?>) -> Void
    
    private let session = URLSession.shared
    private let baseURL = URL(string: "https://jsonplaceholder.typicode.com")!
    
    func perform(_ request: APIRequest, _ completion: @escaping APIClientCompletion) {
        
        var urlComponents = URLComponents()
        urlComponents.scheme = baseURL.scheme
        urlComponents.host = baseURL.host
        urlComponents.path = baseURL.path
        urlComponents.queryItems = request.queryItems
        
        guard let url = urlComponents.url?.appendingPathComponent(request.path) else {
            completion(.failure(.invalidURL)); return
        }
        print(url)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        
        request.headers?.forEach { urlRequest.addValue($0.value, forHTTPHeaderField: $0.field) }
        
        let task = session.dataTask(with: urlRequest) { (data, response, error) in
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.requestFailed)); return
            }
            guard let data = data else { return }
            if let jsonResponse = (try? JSONSerialization.jsonObject(with: data, options: [])) as? NSDictionary
            {
                print(jsonResponse)
            }
            completion(.success(APIResponse<Data?>(statusCode: httpResponse.statusCode, body: data)))
        }
        task.resume()
    }
}


//GET METHOD EXAMPLE

// MARK: - WelcomeElement
struct User: Codable {
    let id: Int
    let name, username, email: String
    let address: Address
    let phone, website: String?
    let company: Company?
}

// MARK: - Address
struct Address: Codable {
    let street, suite, city, zipcode: String
    let geo: Geo
}

// MARK: - Geo
struct Geo: Codable {
    let lat, lng: String
}

// MARK: - Company
struct Company: Codable {
    let name, catchPhrase, bs: String
}

let getRequest = APIRequest(method: .get, path: "users")

APIClient().perform(getRequest) { (result) in
    switch result {
    case .success(let response):
        if let response = try? response.decode(to: [User].self) {
            let users = response.body
            print("Received posts: \(users.first?.name ?? "")")
        }
        else {
            print(response.body)
            print("Failed to decode response")
        }
    case .failure:
        print("Error perform network request")
    }
}



//POST METHOD EXAMPLE

struct Post: Codable {
    let userID, id: Int
    let title, body: String

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case id, title, body
    }
}

let headers = [
    HTTPHeader(field: "content-type", value: "application/json"),
]

let postParameters = [
    "title": "foo",
    "body": "bar",
    "userId": 1
    ] as [String : AnyObject]

let postRequest = APIRequest(method: .post, path: "posts", headers: headers, body: postParameters.getData())

APIClient().perform(postRequest) { (result) in
    switch result {
    case .success(let response):
        if let response = try? response.decode(to: Post.self) {
            let post = response.body
            print("Received posts: \(post)")
        }
        else {
            print(response.body)
            print("Failed to decode response")
        }
    case .failure:
        print("Error perform network request")
    }
}

extension Dictionary {
    var json: String {
        let invalidJson = "Not a valid JSON"
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            return String(bytes: jsonData, encoding: String.Encoding.utf8) ?? invalidJson
        } catch {
            return invalidJson
        }
    }
    
    func printJson() {
        print(json)
    }
    
    func getData() -> Data {
        let jsonData = try! JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
        return jsonData
    }
}

PlaygroundPage.current.needsIndefiniteExecution = true



