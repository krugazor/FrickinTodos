//
//  File.swift
//  
//
//  Created by Zino on 14/12/2019.
//

import Foundation
import HtmlKituraSupport

enum TodoStatus : String, Codable {
    case pending
    case done
    case delayed
    
    static var asXSource : String {
        return """
        [{value: 'pending', text: 'pending'},{value: 'done', text: 'done'},{value: 'delayed', text: 'delayed'}]
        """
    }
    
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
    
    var asHtmlNode : Node {
        return Node.fragment([
            .h3(
                .span(attributes: [.id(self.editid)], .img(src: "/edit.png", alt: "Edit")),
                .span(attributes: [.id(self.titleid)], .text(self.title))
            ),
            .div(
                .div(attributes: [],
                     .img(attributes: [.id(self.statusid), .src(self.imageName), .alt(self.status.rawValue), .height(.px(24)), .width(.px(24))]),
                     .span(.raw("&nbsp;")),
                     .span(attributes:[.id(self.statusid + "t"), .class("status-text")], .text(self.status.rawValue))
                ),
                .div(attributes: [],
                     .span(attributes: [.id(self.commentid)], .text(self.comment ?? " "))
                )
            )
        ])
        
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
