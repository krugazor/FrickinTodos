import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import HeliumLogger

import HtmlKituraSupport
import Kitura
import KituraSession
import KituraSessionRedis
import KituraCompression
import DictionaryCoding

func loadTodos(from s: SessionState?) -> TodoList {
    if let t = s?["todos"] as? TodoList {
        return t
    } else if let t = try? DictionaryCoding().decode(TodoList.self, from: s?["todos"]) {
        return t
    }
    let t = [
        Todo(id: UUID(), title: "New Item", comment: nil, status: .pending),
    ]
    let l = TodoList(t)
    saveTodos(l, to: s)
    return l
}

func saveTodos(_ t: TodoList, to session: SessionState?) {
    session?["todos"] = t
    session?.save(callback: { (err) in
        if let err = err { print("Error saving session: \(err.localizedDescription)") }
    })
}

func editableBlurbJS(_ uidVariable: String) -> String {
    return """
    $('#'+\(uidVariable)+'_t').editable({
    type:  'text',
    pk:    \(uidVariable),
    name:  'title',
    url:   '/change',
    title: 'Title',
    toggle: 'dblclick'
    });
    
    $('#'+\(uidVariable)+'_c').editable({
    type:  'textarea',
    pk:    \(uidVariable),
    name:  'comment',
    url:   '/change',
    title: 'Comment',
    toggle: 'dblclick',
    mode: 'inline',
    inputclass: 'input-comment-edit'
    });
    
    $('#'+\(uidVariable)+'_s').editable({
    type:  'select',
    pk:    \(uidVariable),
    name:  'status',
    url:   '/change',
    title: 'Status',
    toggle: 'click',
    mode: 'inline',
    source: \(TodoStatus.asXSource),
    defaultValue: 'pending',
    success: function(response, newValue) {
    if(!response.success) return response.msg;
    switch(newValue) {
    case '\(TodoStatus.done.rawValue)':
    $('#'+\(uidVariable)+'_s').attr("src","\(TodoStatus.done.imageName)");
    $('#'+\(uidVariable)+'_st').text('\(TodoStatus.done.rawValue)');
    break;
    case '\(TodoStatus.pending.rawValue)':
    $('#'+\(uidVariable)+'_s').attr("src","\(TodoStatus.pending.imageName)");
    $('#'+\(uidVariable)+'_st').text('\(TodoStatus.pending.rawValue)');
    break;
    case '\(TodoStatus.delayed.rawValue)':
    $('#'+\(uidVariable)+'_s').attr("src","\(TodoStatus.delayed.imageName)");
    $('#'+\(uidVariable)+'_st').text('\(TodoStatus.delayed.rawValue)');
    break;
    default:
    break;
    }
    }
    });
    
    $('#'+\(uidVariable)+'_e').click(function(e){
    e.stopPropagation();
    $('#'+\(uidVariable)+'_t').editable('toggle');
    });
    """
}

HeliumLogger.use()

let router = Router()
let redisStore = RedisStore(redisHost: "127.0.0.1", redisPort: 6379, redisPassword: "zxcvbnm", db: 1)
let session = Session(secret: "okmijnuhb", store: redisStore)

router.all(middleware: session, StaticFileServer(path: "./Public"), BodyParser(), Compression())

router.get("/") { request, response, next in
    let todos = loadTodos(from: request.session)
    
    let rendered = todos.list.map { $0.asHtmlNode }
    let editables = todos.list.map { t in
        return """
        $('#\(t.titleid)').editable({
        type:  'text',
        pk:    '\(t.id.uuidString)',
        name:  'title',
        url:   '/change',
        title: 'Title',
        toggle: 'dblclick'
        });
        
        $('#\(t.commentid)').editable({
        type:  'textarea',
        pk:    '\(t.id.uuidString)',
        name:  'comment',
        url:   '/change',
        title: 'Comment',
        toggle: 'dblclick',
        mode: 'inline',
        inputclass: 'input-comment-edit'
        });
        
        $('#\(t.statusid)').editable({
        type:  'select',
        pk:    '\(t.id.uuidString)',
        name:  'status',
        url:   '/change',
        title: 'Status',
        toggle: 'click',
        mode: 'inline',
        source: \(TodoStatus.asXSource),
        defaultValue: '\(t.status.rawValue)',
        success: function(response, newValue) {
        if(!response.success) return response.msg;
        switch(newValue) {
        case '\(TodoStatus.done.rawValue)':
        $("#\(t.statusid)").attr("src","\(TodoStatus.done.imageName)");
        $("#\(t.statusid+"t")").text('\(TodoStatus.done.rawValue)');
        break;
        case '\(TodoStatus.pending.rawValue)':
        $("#\(t.statusid)").attr("src","\(TodoStatus.pending.imageName)");
        $("#\(t.statusid+"t")").text('\(TodoStatus.pending.rawValue)');
        break;
        case '\(TodoStatus.delayed.rawValue)':
        $("#\(t.statusid)").attr("src","\(TodoStatus.delayed.imageName)");
        $("#\(t.statusid+"t")").text('\(TodoStatus.delayed.rawValue)');
        break;
        default:
        break;
        }
        }
        });
        
        $('#\(t.editid)').click(function(e){
        e.stopPropagation();
        $('#\(t.titleid)').editable('toggle');
        });
        """
    }
    var editscript = "$(document).ready(function() {\n"
    for e in editables { editscript += e }
    editscript += "});\n"
    
    response.send(
        Node.fragment([
            Node.doctype("html"),
            Node.html(
                .head(
                    .meta(name: "charset", content: "utf-8"),
                    .meta(name: "viewport", content: "width=device-width, initial-scale=1, shrink-to-fit=no"),
                    .link(attributes: [.rel(.stylesheet), .href("https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css")]),
                    .link(attributes: [.rel(.stylesheet), .href("https://cdnjs.cloudflare.com/ajax/libs/x-editable/1.5.1/jqueryui-editable/css/jqueryui-editable.css")]),
                    .link(attributes: [.rel(.stylesheet), .href("https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.10.4/css/jquery-ui.css")]),
                    .link(attributes: [.rel(.stylesheet), .href("/main.css")]),
                    .script(attributes: [.src("https://code.jquery.com/jquery-1.11.2.js")]),
                    .script(attributes: [.src("https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js")]),
                    .script(attributes: [.src("https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.10.4/jquery-ui.js")]),
                    .script(attributes: [.src("https://cdnjs.cloudflare.com/ajax/libs/poshytip/1.2/jquery.poshytip.min.js")]),
                    .script(attributes: [.src("https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.3/umd/popper.min.js")]),
                    .script(attributes: [.src("https://cdnjs.cloudflare.com/ajax/libs/x-editable/1.5.1/jqueryui-editable/js/jqueryui-editable.min.js")]),
                    .script(attributes: [.src("https://cdnjs.cloudflare.com/ajax/libs/clipboard.js/2.0.4/clipboard.min.js")])
                ),
                .body(
                    .iframe(attributes: [.id("dliframe"), .style(unsafe: "display:none;")], .raw("") ),
                    
                    .div(attributes: [.class("col-sm-6")],
                         .div(attributes: [],
                              .button(attributes: [.title(""), .id("shareBtn"), .class("button-hover"), .data("clipboard-text", request.urlURL.absoluteString+"restore?ssid=\(todos.id.tinyWord)")],
                                      .span(.text("Share this (\(todos.id.tinyWord))"))
                            )
                        ),
                         .div(attributes: [.id("accordion")],
                              .fragment(rendered)
                        ),
                         .div(
                            .span(attributes: [.style(unsafe: "float: left;")],
                                  .input(attributes: [.type(.image), .src("/add.png"), .alt("add"), .onclick(unsafe: "newtodo();")]),
                                  .input(attributes: [.type(.image), .src("/clear.png"), .alt("clear"), .onclick(unsafe: "cleartodos();")])
                            ),
                            .span(attributes: [.style(unsafe: "float: right;")],
                                  .input(attributes: [.type(.image), .src("/export.png"), .alt("export"), .onclick(unsafe: "getmd();")]),
                                  .input(attributes: [.type(.image), .src("/next.png"), .alt("skip"), .onclick(unsafe: "nextMeeting();")])
                            )
                        )
                    ),
                    Node.script(unsafe: editscript),
                    Node.script(unsafe: """
                    $( function() {
                      $( "#accordion" ).accordion({
                        heightStyle: "content"
                      });
                        
                      var btn = document.getElementById('shareBtn');
                      var clipboard = new ClipboardJS(btn);
                      clipboard.on('success', function(e) {
                        $.get("/share"); // make sure we save
                        $('#shareBtn').tooltip( {
                          content: "Copied to clipboard",
                          show: { duration: 200 },
                          hide: { duration: 200, delay: 200 }
                        }).tooltip("open");
                      });
                    } );

                    // from https://stackoverflow.com/questions/105034/create-guid-uuid-in-javascript
                    function uuidv4() {
                      return ([1e7]+-1e3+-4e3+-8e3+-1e11).replace(/[018]/g, c =>
                        (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
                      );
                    }
                    
                    function getmd() {
                        document.getElementById('dliframe').src = '/download';
                    };

                    function newtodo() {
                      let id = uuidv4();
                      $('#accordion').append( " \
                        <h3><span id='"+id+"_e'><img src='/edit.png' alt='Edit' /> \
                        <span id='"+id+"_t'>New</span> \
                        </h3> \
                        <div><div><img id='"+id+"_s' src='/pending.png' alt='pending' height='24px' width='24px' /><span>&nbsp;</span><span id='"+id+"_st'>pending</span></div> \
                             <div><span id='"+id+"_c'></span></div> \
                        </div> \
                      ");
                      $( "#accordion" ).accordion("refresh");

                      \(editableBlurbJS("id"))
                        
                      $.post("/new", { "id": id });
                    }
                        
                    function cleartodos() {
                        $('<div id="dialog-confirm" title="Remove all notes?"><p>You will lose everything!</p></div>').dialog({
                          resizable: false,
                          height: "auto",
                          modal: true,
                          buttons: {
                            "NO": function() { $( this ).dialog( "close" ); },
                            "Sure": function() {
                              $.post("/clear");
                              $('#accordion').empty();
                              newtodo();
                              $( this ).dialog( "close" );
                            }
                          }
                        });
                    }
                        
                    function nextMeeting() {
                      var done = true;
                      $("span").each( function(index, element) {
                        if( element.className === "status-text" ) {
                          done = done && ( element.innerHTML !== '\(TodoStatus.pending.rawValue)' );
                        }
                      });
                      if( !done ) {
                        $('<div id="dialog" title="Error"><p>All items must either be dealt with or delayed</p></div').dialog();
                      } else {
                        $('<div id="dialog-confirm" title="Move to the next meeting?"><p>You will lose the tasks that have been done!</p></div>').dialog({
                          resizable: false,
                          height: "auto",
                          modal: true,
                          buttons: {
                            "Download current notes": function() { getmd(); },
                            "Next meeting": function() {
                              $.post("/next", function( data ) {
                                location.reload();
                              });
                            }
                          }
                        });
                      }
                    }
                    """)
                    
                )
            )
        ])
    )
    response.headers.setType("html", charset: "utf-8")
    
    next()
}

let df = DateFormatter()
df.dateStyle = .short
df.timeStyle = .short
router.get("/download") { request, response, next in
    let notes = loadTodos(from: request.session)
    
    let output = "### Notes (\(df.string(from: Date())))\n\n" + notes.toMarkdown
    
    if let d = output.data(using: .utf8) {
        response.headers.setType("application/octet-stream")
        response.headers.addAttachment(for: "CR.md")
        response.send(data: d)
    }
    
    next()
}

router.post("/clear") { request, response, next in
    saveTodos(TodoList(), to: request.session)
    response.send(json: ["success": true])
    next()
}

router.post("/new") { request, response, next in
    if let b = request.body, let c = b.asURLEncoded, let uid = c["id"], let uuid = UUID(uuidString: uid) {
        var todos = loadTodos(from: request.session)
        // save and move on
        permanentlyStore(todos, callback: {_ in })
        
        todos = TodoList()
        todos.list.append(Todo(id: uuid, title: "New", comment: "", status: .pending))
        saveTodos(todos, to: request.session)
        response.send(json: ["success": true])
    } else {
        response.send(json: ["success": false])
    }
    
    next()
}

router.post("/change") { request, response, next in
    if let b = request.body, let c = b.asURLEncoded {
        var list = loadTodos(from: request.session)
        var notes = list.list
        switch c["name"] {
        case "title":
            if let pk = c["pk"], let pkid = UUID(uuidString: pk), let noteidx = notes.firstIndex(where: { $0.id == pkid } ) {
                var note = notes[noteidx]
                note.title = c["value"] ?? ""
                notes[noteidx] = note
            }
        case "comment":
            if let pk = c["pk"], let pkid = UUID(uuidString: pk), let noteidx = notes.firstIndex(where: { $0.id == pkid } ) {
                var note = notes[noteidx]
                note.comment = c["value"] ?? ""
                notes[noteidx] = note
            }
        case "status":
            if let pk = c["pk"], let pkid = UUID(uuidString: pk), let noteidx = notes.firstIndex(where: { $0.id == pkid } ) {
                var note = notes[noteidx]
                note.status = TodoStatus(rawValue: c["value"] ?? "") ?? .delayed
                notes[noteidx] = note
            }
        default:
            response.send(json: ["success": false])
            next()
            return
        }
        
        list.list = notes
        saveTodos(list, to: request.session)
        response.send(json: ["success": true])
    } else {
        response.send(json: ["success": false])
    }
    
    next()
}

router.post("/next") { request, response, next in
    // save and move on
    let old = loadTodos(from: request.session)
    permanentlyStore(old, callback: {_ in })

    let todos = old.list.filter { $0.status != .done }.map {
        return Todo(id: $0.id, title: $0.title, comment: $0.comment, status: .pending)
    }
    saveTodos(TodoList(todos), to: request.session)
    response.send(json: ["success": true])
}

router.get("/share") { request, response, next in
    let notes = loadTodos(from: request.session)
    permanentlyStore(notes) { (result) in
        print("Stored session: \(result)")
        response.send(json: ["success": result])
        next()
    }
}

router.get("/restore") { request, response, next in
    guard let ssids = request.queryParameters["ssid"] else {
        response.status(.notFound)
        next()
        return
    }
    guard let ssid = UUID(tinyWord: ssids) else {
        response.status(.notFound)
        next()
        return
    }
    
    restoreFromPermanent(for: ssid) { (todos) in
        if todos.list.count == 0 && loadTodos(from: request.session).list.count != 0 {
            // hmmmmm maybe not a good idea?
            next()
            return
        }
        
        saveTodos(todos, to: request.session)
        _ = try? response.redirect("/")
        next()
    }
}

Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()
