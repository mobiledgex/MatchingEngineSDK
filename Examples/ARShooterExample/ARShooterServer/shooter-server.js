var io = require('socket.io')(1337) // Listen on port 1337
//const nameSpace = "/arshooter"
//const ARShooterIO = io.of(nameSpace);

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
            socket.username = username;
            socket.gameID = gameID;
            socket.join(gameID, function(err) {
                console.log("After join: ", socket.rooms);
                console.log("gamid: " + gameID + ", username " + username);
                console.log(scores);
                io.in(gameID).emit("otherUsers", scores);  // send self all other usernames and score
            });
            console.log("no repeat username");

        }
    });

    socket.on("bullet", function(gameID, bullet) {
        socket.to(gameID).emit("bullet", bullet);
        console.log("bullet is ");
        console.log(bullet);
    });

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
    
    socket.on('disconnect', function(reason) {
        var username = socket.username;
        var gameID = socket.gameID
        var gameScores = scoreInGameMap.get(gameID);
        delete gameScores[username];
        scoreInGameMap.set(gameID, gameScores);
        io.in(gameID).emit("otherUsers", gameScores);
        console.log(reason);
    });
});
