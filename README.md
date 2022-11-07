# SpannerCloudGame
Building a game on google cloud with a spanner 

Created four Go services that interact with a regional Spanner database. The first two services, profile-service and matchmaking-service, enable players to sign up and start playing. The second pair of services, item-service and tradepost-service, enable players to acquire items and money, and then list items on the trading post for other players to purchase.

Generated data leveraging the Python load framework Locust.io to simulate players signing up and playing games to obtain games_played and games_won statistics. Also allowed players to acquire money and items through the course of "game play". Players can then list items for sale on a tradepost, where other players with enough money can purchase those items.

Query  Spanner to determine how many players are playing, statistics about players' games won versus games played, players' account balances and number of items, and statistics about trade orders that are open or have been filled.

