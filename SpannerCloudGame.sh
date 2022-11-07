#Google Cloud Spanner is a fully managed horizontally scalable, globally distributed, relational database service that provides ACID transactions and SQL semantics 
#without giving up performance and high availability. 
#These features makes Spanner a great fit in the architecture of games that want to enable a global player base or are concerned about data consistency
#as it give you the ability to scale, data consistency and abilty to manage overhead
#horizontal database

#Im creating four Go services that interact with a regional Spanner database. 
#The first two services, profile-service and matchmaking-service, enable players to sign up and start playing. 
#The second pair of services, item-service and tradepost-service, enable players to acquire items and money, 
#and then list items on the trading post for other players to purchase.

#I will then generate data leveraging the Python load framework Locust.io to simulate players signing up 
#and playing games to obtain games_played and games_won statistics. 
#Players will also acquire money and items through the course of "game play". 
#Players can then list items for sale on a tradepost, where other players with enough money can purchase those items.

#query Spanner to determine how many players are playing, statistics about players' games won versus games played, 
#players' account balances and number of items, and statistics about trade orders that are open or have been filled.


#Locust is a Python load testing framework that is useful to test REST API endpoints


#Task 1- Setting up a Locust Load Generator 
#Im creating two different load test generators 
#authentication_server.py: contains tasks to create players and to get a random player to imitate single point lookups.
#match_server.py: contains tasks to create games and close games. Creating games will assign 100 random players that aren't currently playing games. 
#Closing games will update games_played and games_won statistics, and allow those players to be assigned to a future game.


#Open cloud console and using this code to clone Spanner Gaming Samples repository:
git clone https://github.com/cloudspannerecosystem/spanner-gaming-sample.git
cd spanner-gaming-sample/

#Make sure Python 3.9 is installed 
python -V
# installing the requirements for Locust.
pip3 install -r requirements.txt
# updating the PATH so that the newly installed locust binary can be found
PATH="~/.local/bin:$PATH"
which locust

#Task 2-Creating a Spanner instance and database
# Go under the Databases section click Spanner.
#Click on Create a Provisioned Instance.

#For Spanner configuration, I use the following:
#Instance name: cloudspanner-gaming
#Configuration: Regional and us-central1
#Processing units: 500

# creating a database called sample-game with google-standard sql dialect with default options, and supplying the schema at creation time
#Creating two tables in the database players and games 
#Players can participate in many games over time, but only one game at a time.
# Players also have stats as a JSON data type to keep track of interesting statistics like games_played and games_won. 
#Because other statistics might be added later, this is effectively a schema-less column for players.
#Games keep track of the players that participated using Spanner's ARRAY data type. 
#A game's winner and finished attributes are not populated until the game is closed out.
#There is one foreign key to ensure the player's current_game is a valid game.

#the schema for games and players table
CREATE TABLE games (
  gameUUID STRING(36) NOT NULL,
  players ARRAY<STRING(36)> NOT NULL,
  winner STRING(36),
  created TIMESTAMP,
  finished TIMESTAMP,
) PRIMARY KEY(gameUUID);
CREATE TABLE players (
  playerUUID STRING(36) NOT NULL,
  player_name STRING(64) NOT NULL,
  email STRING(MAX) NOT NULL,
  password_hash BYTES(60) NOT NULL,
  created TIMESTAMP,
  updated TIMESTAMP,
  stats JSON,
  account_balance NUMERIC NOT NULL DEFAULT (0.00),
  is_logged_in BOOL,
  last_login TIMESTAMP,
  valid_email BOOL,
  current_game STRING(36),
  FOREIGN KEY (current_game) REFERENCES games (gameUUID),
) PRIMARY KEY(playerUUID);
CREATE UNIQUE INDEX PlayerAuthentication ON players(email) STORING (password_hash);
CREATE INDEX PlayerGame ON players(current_game);
CREATE UNIQUE INDEX PlayerName ON players(player_name);

#setting the following enivorment variables into cloud shell
export PROJECT_ID=$(gcloud config get-value project)
export SPANNER_PROJECT_ID=$PROJECT_ID
export SPANNER_INSTANCE_ID=cloudspanner-gaming
export SPANNER_DATABASE_ID=sample-game

#Task 3 Deploy the profile service to allow players to sign up to play the game

#​​The profile service is a REST API written in Go that leverages the gin framework. 
#In this API, players can sign up to play games. 
#This is created by a simple POST command that accepts a player name, email and password. 
#The password is encrypted with bcrypt and the hash is stored in the database.


#Run the service using the following Go command below. This will download dependencies, and establish the service running on port 8080:
cd ~/spanner-gaming-sample/src/golang/profile-service
go run . &

#testing the service issuing a curl command
curl http://localhost:8080/players \
    --include \
    --header "Content-Type: application/json" \
    --request "POST" \
    --data '{"email": "test@gmail.com","password": "s3cur3P@ss","player_name": "Test Player"}'

#Task 4 deploy the matchmaking service
#using a rest api written in go
#In this API, games are created and closed. When a game is created, 100 players who are not currently playing a game are assigned to the game.
#When a game is closed, a winner is randomly selected 
#and each players' stats for games_played and games_won are adjusted. 
#Also, each player is updated to indicate they are no longer playing and so are available to play future games.

#   In Cloud Shell, re-run the following commands to set the following environment variables:

export PROJECT_ID=$(gcloud config get-value project)
export SPANNER_PROJECT_ID=$PROJECT_ID
export SPANNER_INSTANCE_ID=cloudspanner-gaming
export SPANNER_DATABASE_ID=sample-game
#Run the service using the go command. 
#This will establish the service running on port 8082. 
#This service has many of the same dependencies as the profile-service, so new dependencies will not be downloaded.
cd ~/spanner-gaming-sample/src/golang/matchmaking-service
go run . &

#Create a game
#issue this curl command
curl http://localhost:8081/games/create \
    --include \
    --header "Content-Type: application/json" \
    --request "POST"
# the UUID output(4fc94ae0-dccd-416c-a0a6-df07b541c261) willl be used to close the game at the end 
# will run this following command to close the game
curl http://localhost:8081/games/close \
    --include \
    --header "Content-Type: application/json" \
    --data '{"gameUUID": "4fc94ae0-dccd-416c-a0a6-df07b541c261"}' \
    --request "PUT"

#Task 5 start playing games
#Now that the profile and matchmaking services are running, going to generate load using provided locust generators.
#running this command to generaye players
cd ~/spanner-gaming-sample
locust -H http://127.0.0.1:8080 -f ./generators/authentication_server.py --headless -u=2 -r=2 -t=30s
#comaand to create and close games(for 10sec)
locust -H http://127.0.0.1:8081 -f ./generators/match_server.py --headless -u=1 -r=1 -t=10s
 # So just simulated players signing up to play games and then ran simulations for players to play games using the matchmaking service. 
 #These simulations leveraged the Locust Python framework to issue requests to the services' REST API

 #Task 6 Retrive various game statistics theough querying spinner 
# go to the sample-game database and query it
#Run the following query to check how many games are open and how many are closed
SELECT Type, NumGames FROM
(SELECT "Open Games" as Type, count(*) as NumGames FROM games WHERE finished IS NULL
UNION ALL
SELECT "Closed Games" as Type, count(*) as NumGames FROM games WHERE finished IS NOT NULL)
#A closed game is one that has the finished timestamp populated, 
#while an open game will have finished being NULL. This value is set when the game is closed.

#Run the following query to compare how many players are currently playing and not playing:
SELECT Type, NumPlayers FROM
(SELECT "Playing" as Type, count(*) as NumPlayers FROM players WHERE current_game IS NOT NULL
UNION ALL
SELECT "Not Playing" as Type, count(*) as NumPlayers FROM players WHERE current_game IS NULL)
#A player is playing a game if their current_game column is set. Otherwise, they are not currently playing a game.

#Run the following query to determine the top winners of the games:
SELECT playerUUID, stats
FROM players
WHERE CAST(JSON_VALUE(stats, "$.games_won") AS INT64)>0
LIMIT 10;
#When a game is closed, one of the players is randomly selected to be the winner. That player's games_won statistic is incremented during closing out the game.

#Task 7 Update the database schema
#add two more services: item-service and tradepost-service.
# going to update the schema to create four new tables: game_items, player_items, player_ledger_entries and trade_orders.
#Game items are added in the game_items table, and then can be acquired by players. 
#The player_items table has foreign keys to both an itemUUID and a playerUUID to ensure players are acquiring only valid items.
#The player_ledger_entries table keeps track of any monetary changes to the player's account balance. 
#This can be acquiring money from loot, or by selling items on the trading post.
#the trade_orders table is used to handle posting sell orders, and for buyers to fulfill those orders.

#Create a schema by clicking the write DDL button
# then add this to update the database with the new tables
CREATE TABLE game_items
(
  itemUUID STRING(36) NOT NULL,
  item_name STRING(MAX) NOT NULL,
  item_value NUMERIC NOT NULL,
  available_time TIMESTAMP NOT NULL,
  duration int64
)PRIMARY KEY (itemUUID);
CREATE TABLE player_items
(
  playerItemUUID STRING(36) NOT NULL,
  playerUUID STRING(36) NOT NULL,
  itemUUID STRING(36) NOT NULL,
  price NUMERIC NOT NULL,
  source STRING(MAX) NOT NULL,
  game_session STRING(36) NOT NULL,
  acquire_time TIMESTAMP NOT NULL DEFAULT (CURRENT_TIMESTAMP()),
  expires_time TIMESTAMP,
  visible BOOL NOT NULL DEFAULT(true),
  FOREIGN KEY (itemUUID) REFERENCES game_items (itemUUID),
  FOREIGN KEY (game_session) REFERENCES games (gameUUID)
) PRIMARY KEY (playerUUID, playerItemUUID),
    INTERLEAVE IN PARENT players ON DELETE CASCADE;
CREATE TABLE player_ledger_entries (
  playerUUID STRING(36) NOT NULL,
  source STRING(MAX) NOT NULL,
  game_session STRING(36) NOT NULL,
  amount NUMERIC NOT NULL,
  entryDate TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
  FOREIGN KEY (game_session) REFERENCES games (gameUUID)
) PRIMARY KEY (playerUUID, entryDate DESC),
  INTERLEAVE IN PARENT players ON DELETE CASCADE;
CREATE TABLE trade_orders
(
  orderUUID STRING(36)  NOT NULL,
  lister STRING(36) NOT NULL,
  buyer STRING(36),
  playerItemUUID STRING(36) NOT NULL,
  trade_type STRING(5) NOT NULL,
  list_price NUMERIC NOT NULL,
  created TIMESTAMP NOT NULL DEFAULT (CURRENT_TIMESTAMP()),
  ended TIMESTAMP,
  expires TIMESTAMP NOT NULL DEFAULT (TIMESTAMP_ADD(CURRENT_TIMESTAMP(), interval 24 HOUR)),
  active BOOL NOT NULL DEFAULT (true),
  cancelled BOOL NOT NULL DEFAULT (false),
  filled BOOL NOT NULL DEFAULT (false),
  expired BOOL NOT NULL DEFAULT (false),
  FOREIGN KEY (playerItemUUID) REFERENCES player_items (playerItemUUID)
) PRIMARY KEY (orderUUID);
CREATE INDEX TradeItem ON trade_orders(playerItemUUID, active);

#Task 8. Deploy the item service
#deploying the item service that allows creation of game items, and players assigned to open games to be able to acquire money and game items using rest api written in GO

# re-run the following commands to set the following environment variables:
export PROJECT_ID=$(gcloud config get-value project)
export SPANNER_PROJECT_ID=$PROJECT_ID
export SPANNER_INSTANCE_ID=cloudspanner-gaming
export SPANNER_DATABASE_ID=sample-game
#run the service to download dependencies and establish the service running on port 8082:
cd ~/spanner-gaming-sample/src/golang/item-service
go run . &
#curl command to create an item
curl http://localhost:8082/items \
    --include \
    --header "Content-Type: application/json" \
    --request "POST" \
    --data '{"item_name": "test_item","item_value": "3.14"}'
    #Next, you want a player to acquire this item. To do that, there needs to be an ItemUUID and PlayerUUID. 
    #The ItemUUID is the output from the previous command. In this example, case it's: aecde380-0a79-48c0-ab5d-0da675d3412c.

#use this command to get the PLayerUUID
curl http://localhost:8082/players

#For the player to acquire the item, make a request to the POST /players/items endpoint:
curl http://localhost:8082/players/items \
    --include \
    --header "Content-Type: application/json" \
    --request "POST" \
    --data '{"playerUUID": "b74cc194-87b0-4a55-a67f-0f0742ef6352","itemUUID": "109ec745-9906-402b-9d03-ca7153a10312", "source": "loot"}'

#Task 9. Deploy the tradepost service
# deploy the tradepost service to handle creating sell orders USING REST API WRITTEN IN GO. This service also handles the ability to buy those orders.
#Players of games can then get open trades, and if they have enough money, can purchase the item.

#Run the following command to run the service. Running the service will establish the service running on port 8083. 
#This service has many of the same dependencies as the item-service, so new dependencies will not be downloaded.
cd ~/spanner-gaming-sample/src/golang/tradepost-service
go run . &
#Test the service by issuing a GET request to retrieve a PlayerItem to sell:
curl http://localhost:8083/trades/player_items

 #the following command  post an item for sale by calling the /trades/sell endpoint. 
 curl http://localhost:8083/trades/sell \
    --include \
    --header "Content-Type: application/json" \
    --request "POST" \
    --data '{"lister": "<PlayerUUID>","playerItemUUID": "<PlayerItemUUID>", "list_price": "<some price higher than items price>"}'

# Task 10. Start trading
# to generate random items with random string names and price run this command
cd ~/spanner-gaming-sample
locust -H http://127.0.0.1:8082 -f ./generators/item_generator.py --headless -u=1 -r=1 -t=10s
#this command allow players to acquire items(30 sec)
cd generators
locust -H http://127.0.0.1:8082 -f game_server.py --headless -u=1 -r=1 -t=30s
#fowllowing command allows players to list items they've acquired for sale, and other players to purchase those item for 10 seconds:
locust -H http://127.0.0.1:8083 -f trading_server.py --headless -u=1 -r=1 -t=10s

#To retrive trade statistics use these commands to query the database


#ollowing query to check how many orders are open and how many are filled:
-- Open vs Filled Orders
SELECT Type, NumTrades FROM
(SELECT "Open Trades" as Type, count(*) as NumTrades FROM trade_orders WHERE active=true
UNION ALL
SELECT "Filled Trades" as Type, count(*) as NumTrades FROM trade_orders WHERE filled=true
)

#Checking player account balance and number of items/
#To get to top 10 players currently playing games with the most items, with their account_balance
SELECT playerUUID, account_balance, (SELECT COUNT(*) FROM player_items WHERE playerUUID=p.PlayerUUID) AS numItems, current_game
FROM players AS p
WHERE current_game IS NOT NULL
ORDER BY numItems DESC
LIMIT 10;




