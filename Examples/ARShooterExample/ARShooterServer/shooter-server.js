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

class GameState {
    constructor(gameID) {
        this.gameID = gameID;
        this.connections = new Set();
        this.usernames = new Set();
        this.peerDict = new Map();   // USE MAP: CONNECTION IS AN OBJECT (USE MAPS FOR DICT/OBJECT) FORMAT
    }

    addClient(connection, username) {
        this.connections.add(connection);
        this.usernames.add(username);
        this.peerDict.set(connection, username);
    }

    removeClient(connection) {
        let username = this.peerDict.get(connection);
        this.connections.delete(connection);
        this.usernames.delete(username);
        this.peerDict.delete(connection);
        console.log(username + " disconnected");
    }

    hasConnection(connection) {
        return this.connections.has(connection);
    }

    hasUsername(username) {
        return this.usernames.has(username);
    }
}

var connectionDict = new Map(); // Connection to GameState Map -> [connection: GameState] USE MAP: CONNECTION IS AN OBJECT
var gameIDDict = {}; // GameID to GameState Dictionary -> [gameID: GameState]

function sendDataToPeers(currConnection, event) {
    console.log("server received data");
    if (!(currConnection in connectionDict)) {
        return;
    }
    var game = connectionDict.get(currConnection);
    var gameConnections = game.connections;
    for (let connection of gameConnections) {
        if (connection != currConnection) {
            connection.send(event.binaryData);
        }
    }
}

function getGame(gameID, username, currConnection, event) {
    console.log("server received gameid and username")
    if (gameID in gameIDDict) {
        let gameState = gameIDDict[gameID];
        if (!connectionDict.has(currConnection)) {
            connectionDict.set(currConnection, gameState);
        }
        return gameState;
    } else {
        let gameState = new GameState(gameID);
        connectionDict.set(currConnection, gameState); // add currConnection and the new GameState to dict
        gameIDDict[gameID] = gameState;  // add gameID and the new GameState to dict
        return gameState;
    }
}

function sendUsernameToPeers(username, currConnection, currGame, event) {
    var peers = currGame.connections;
    for (let peer of peers) {   // send all users current username
        if (peer != currConnection) {
            console.log("sending other users curr username");
            peer.send("" + username);  // quiets compile error
        }
    }
}

function sendPeerUsernamesToSelf(username, currConnection, currGame, event) {
    var usernames = currGame.usernames;
    for (let name of usernames) {   // send current user all other usernames
        if (name != username) {
            console.log("sending myself other usernames");
            currConnection.send(name);
        }
    }
}

wsServer.on('request', function(request) {

    console.log((new Date()) + "Connection from origin " + request.origin + "."); 
    var currConnection = request.accept("arshooter", request.origin);
    console.log("connection is " + currConnection);
    
    currConnection.on('message', function(event) {
        console.log(JSON.stringify(event));
        switch (event.type) {
        // receive some action
        case 'binary': 
            sendDataToPeers(currConnection, event);
            return;
        // receive gameid and username
        case 'utf8':
            var arr = event.utf8Data.split(":"); // Parse gameID and userName 
            var gameID = arr[0];
            var username = arr[1];

            var currGame = getGame(gameID, username, currConnection, event);
            
            if (!currGame.hasUsername(username)) {
                currGame.addClient(currConnection, username);
                sendUsernameToPeers(username, currConnection, currGame, event);
                sendPeerUsernamesToSelf(username, currConnection, currGame, event);
            } else {
                currConnection.send("Username already in use");
            }
            return;
        }
    });

    currConnection.on('close', function(connection) {
        let currGame = connectionDict.get(currConnection);
        console.log("currGame is " + currGame);
        currGame.removeClient(currConnection);
        connectionDict.delete(currConnection);
    });
});
