var WebSocketServer = require('websocket').server;
var http = require('http');

var server = http.createServer(function(request, response) {
});
server.listen(1337, function() {
    console.log((new Date()) + "Server is listening on port 1337");
});

var wsServer = new WebSocketServer({
    httpServer: server
});

var games = {};
var clients = new Set([]);
var usernames = new Set([]); // kept separate so server can't see which username goes with which connection

wsServer.on('request', function(request) {
    console.log((new Date()) + "Connection from origin " + request.origin + "."); 
    var connection = request.accept("arshooter", request.origin);
    
    clients.add(connection)
    
    connection.on('message', function(event) {
        console.log(JSON.stringify(event))
        switch (event.type) {
        // receive some action
        case 'binary':  
            console.log("server received message"); 
            for (let client of clients) {
                if (client != connection) {
                    client.send(event.binaryData);
                }
            }
            return;
        // receive username (handle repeat usernames)
        case 'utf8':  
            console.log("server received username");
            if (!usernames.has(event.utf8Data)) {
                usernames.add(event.utf8Data);
                for (let client of clients) {   // send all users current username
                    if (client != connection) {
                        console.log("sending other users curr username");
                        client.send("" + event.utf8Data);  // quiets compile error
                    }
                }
                for (let username of usernames) {   // send current user all other usernames
                    if (username != event.utf8Data) {
                        console.log("sending myself other usernames");
                        connection.send(username);
                    }
                }
            } else {
                connection.send("Username already in use");
            }
            return;
        }
    });

    connection.on('close', function(connection) {
    });
});
