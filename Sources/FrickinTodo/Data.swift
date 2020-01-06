//
//  File.swift
//  
//
//  Created by Zino on 14/12/2019.
//

import Foundation
import HtmlKituraSupport
import SwiftRedis

enum TodoStatus : String, Codable {
    case pending
    case done
    case delayed
    
    var imageName : String {
        return "/"+self.rawValue+".png"
    }
}

struct Todo : Codable {
    var id: UUID = UUID()
    var title: String
    var comment: String?
    var status : TodoStatus
    
    var todoid : String { return "t"+self.id.uuidString.replacingOccurrences(of: "-", with: "") }
    var editid : String { return self.todoid+"_e" }
    var titleid : String { return self.todoid+"_t" }
    var commentid : String { return self.todoid+"_c" }
    var statusid : String { return self.todoid+"_s" }
    
    var imageName : String {
        return status.imageName
    }
}

extension Array where Element == Todo {
    var toMarkdown : String {
        var result = ""
        for t in self {
            result += "#### "+t.title+"\n\n"
            result += (t.comment ?? "") + "\n\n"
            result += "Status: " + t.status.rawValue + "\n\n"
        }
        
        return result
    }
}

struct TodoList : Codable {
    var id : UUID = UUID()
    var list : [Todo]
    
    var toMarkdown : String { return list.toMarkdown }
    
    init() {
        list = []
    }
    
    init(_ l: [Todo]) {
        list = l
    }
    
    init(_ other: TodoList) {
        list = other.list
    }
}

// MARK: -

extension UUID {
    static let charmap = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n",
                          "o","p","q","r","s","t","u","v","w","x","y","z",
                          "A","B","C","D","E","F","G","H","I","J","K","L","M","N",
                          "O","P","Q","R","S","T","U","V","W","X","Y","Z",
                          "0","1","2","3","4","5","6","7","8","9","-","+"]
    static let charmapSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-+"
    
    var tinyWord : String {
        let from = self.uuid
        let bytes = [from.0, from.1, from.2,from.3,from.4,from.5,from.6,from.7,from.8,from.9,
                     from.10, from.11, from.12,from.13,from.14,from.15]
        
        // split in 6-bits ints
        var sbytes : [UInt8] = []
        for i in 0..<5 {
            let b1 = bytes[i*3]
            let b2 = bytes[i*3+1]
            let b3 = bytes[i*3+2]
            
            let sb1 = b1 >> 2
            let sb2 = (b1 & 0x03) << 4 | (b2 >> 4)
            let sb3 = (b2 & 0x0f) << 2 | (b3 >> 6)
            let sb4 = (b3 & 0x3f)
            sbytes += [sb1,sb2,sb3,sb4]
        }
        // all done but the last byte
        sbytes.append(bytes[15]>>2)
        sbytes.append(bytes[15]&0x03)
        
        var result = ""
        for i in sbytes {
            result += UUID.charmap[Int(i)]
        }
        
        return result
    }
}

extension UUID {
    init?(tinyWord: String) {
        if tinyWord.count != 22 || !tinyWord.allSatisfy({ UUID.charmapSet.contains($0) }) { return nil }
        var current : UInt8 = 0
        var bytes : [UInt8] = []
        for (n,c) in tinyWord.enumerated() {
            guard let idx32 = UUID.charmap.firstIndex(of: String(c)) else { return nil }
            let idx = UInt8(idx32)
            if n >= 20 { // last byte
                if n == 20 {
                    current = idx << 2
                } else {
                    current |= idx
                    bytes.append(current)
                }
            } else if n % 4 == 0 { // first in cycle
                current = idx << 2
            } else if n % 4 == 1 { // combine
                current |= idx >> 4
                bytes.append(current)
                current = (idx & 0xf) << 4
            } else if n % 4 == 2 { // combine
                current |= (idx >> 2)
                bytes.append(current)
                current = (idx & 0x3) << 6
            } else {
                current |= idx
                bytes.append(current)
                current = 0
            }
        }
        
        // double check
        if bytes.count != 16 { return nil }
        
        self.init(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9],
                         bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

// MARK: -

func permanentlyStore(_ todos : TodoList, callback: @escaping (Bool)->Void) {
    let redis = Redis()
    redis.connect(host: redisStore.redisHost, port: redisStore.redisPort) { error in
        guard error == nil else {
            callback(false)
            return
        }
        if let redisPassword = redisStore.redisPassword {
            redis.auth(redisPassword) { error in
                guard error == nil else {
                    callback(false)
                    return
                }
                redis.select(2) { error in // sessions in db1, longer term storage in db2
                    guard error == nil else {
                        callback(false)
                        return
                    }
                    // using JSON... 🤷‍♂️
                    if let encoded = try? JSONEncoder().encode(todos), let serialized = String(data: encoded, encoding: .utf8) {
                        redis.set(todos.id.tinyWord, value: serialized, exists: nil, expiresIn: 4*24*3600) { (r, error) in // stored for 4 weeks
                            guard error == nil else {
                                callback(false)
                                return
                            }
                            callback(r)
                        }
                    }
                }
            }
        }
    }
}

func restoreFromPermanent(for id: UUID, callback: @escaping (TodoList)->Void) {
    let redis = Redis()
    redis.connect(host: redisStore.redisHost, port: redisStore.redisPort) { error in
        guard error == nil else {
            callback(TodoList())
            return
        }
        if let redisPassword = redisStore.redisPassword {
            redis.auth(redisPassword) { error in
                guard error == nil else {
                    callback(TodoList())
                    return
                }
                redis.select(2) { error in // sessions in db1, longer term storage in db2
                    guard error == nil else {
                        callback(TodoList())
                        return
                    }
                    
                    redis.get(id.tinyWord) { (s, error) in
                        guard error == nil else {
                            callback(TodoList())
                            return
                        }

                        if let encoded = s?.asData, let todos = try? JSONDecoder().decode(TodoList.self, from: encoded) {
                            callback(todos)
                        } else {
                            callback(TodoList())
                        }
                    }
                }
            }
        }
    }
}
