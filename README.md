business_logic
=====

Built using gen_servers and supervisors to provide the logic for interacting with the database and recieving events sent by the [frontend service](https://github.com/electricman991/cowboy_frontend). There are four gen_servers that each handle a specific event sent by a delivery truck. When one of those events is sent it gets handled by the gen_server and then will interact with the database to receive the needed information or store new information for a package. Here is an overview of the application 

![image](https://github.com/user-attachments/assets/3adf1128-068f-43c7-b595-97b6bcf17e46)

Start the backend logic with this command
```bash
rebar3 shell --name business_logic@business.parallelcompute.net --setcookie secret
```
This command will start the node business_logic at the specified domain. This will allow for erpc to make calls from the frontend_service.

# Check Riak buckets using API
If needed check the buckets for riak using the API endpoints

curl http://RIAK_SERVER_IP:8098/buckets?buckets=true

Check a specific bucket for its keys

curl http://RIAK_SERVER_IP:8098/buckets/BUCKET_NAME/keys?key=true

# Logger
Add an event handler using gen_event:add_handler(logger_event, logger_event, standard_io) will log to console
