var io = require('socket.io')(1337) // Listen on port 1337
//const nameSpace = "/arshooter"
//const ARShooterIO = io.of(nameSpace);

class GameState {
    constructor(gameID) {
        this.gameID = gameID;
        this.connections = new Set();
        this.usernames = new Set();
        this.peerDict = new Map();
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

var connectionDict = new Map(); // Connection to GameState Map -> [connection: GameState]
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

var scoreInGameMap = new Map(); // Map gameID to Map of usernames and score in that game

io.on('connection', function(socket) {

    console.log((new Date()) + "Connection from origin " + socket + "."); 

    socket.on("login", function(gameID, username) {
        console.log("gamid: " + gameID + ", username " + username);
        if (!scoreInGameMap.has(gameID)) {
            console.log("no game with that name yet");
            var scores = {};
            scoreInGameMap.set(gameID, scores);
        }
        var scores = scoreInGameMap.get(gameID);
        if (username in scores) {
            socket.emit("repeatUsername", "Username already being used. Choose a different one.");
        } else {
            scores[username] = 0;
            scoreInGameMap.set(gameID, scores);
            socket.join(gameID, function(err) {
                console.log("After join: ", socket.rooms);
                console.log("gamid: " + gameID + ", username " + username);
                console.log(scores);
                io.in(gameID).emit("otherUsers", scores);  // send self all other usernames and score
                //ARShooterIO.to(gameID).emit("username", username); // send other users current username
            });
            console.log("no repeat username");

        }
    });

    socket.on("bullet", function(gameID, bullet) {
        socket.to(gameID).emit("bullet", bullet);
        console.log("bullet is ");
        console.log(bullet);
    });

    //var worldMapBuffer = new Blob()
    socket.on("worldMap", function(gameID, worldMap) {
        socket.to(gameID).emit("worldMap", worldMap);
        console.log("worldMap is ");
        console.log(worldMap);
    });

    socket.on("score", function(gameID, username) {
        console.log("score");
    });

    socket.on("error", function(err) {
        console.log("Caught flash policy server socket error: ");
        console.log(err.stack);
    });
    
    //currConnection.on('close', function(connection) {
    //socket.on('disconnect', function(connection) {
        //let currGame = connectionDict.get(currConnection);
        //console.log("currGame is " + currGame);
        //currGame.removeClient(currConnection);
        //connectionDict.delete(currConnection);
    //});
});
