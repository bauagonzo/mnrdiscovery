#mnrdiscovery

```mnrdiscovery``` is a CLI to test devices accessibility from EMC SRM and other M&R products.

#Description
That script can be used in the SRM installation to connect to the MnR Discovery page and run the test functionality for the discovered devices. The results of the test can be sent to the SRM administrator so he can fix any problem proactively. 

#Use Cases

1. The script is installed within an SRM task in one of the backend and an email is sent to the SRM administrator with the script results attached. 
2. The script is installed within an SRM task and the results are sent within traps to the Alert Consolidation module so the test that failed result in an Alert that is added to the events databases and sent by email. 


#Usage
The script can be run on any server that can reach the SRM FrontEnd WebService. If it's run outside of the SRM Frontend server the hostname parameter is a must. 
```shell
ruby mnrdiscovery.rb --help                                                                                                                          1 ↵
Usage: mnrdiscovery [options]
    -h, --host [hostname]            frontend host
    -u, --user [username]            frontend username
    -p, --password [*****]           frontend password
        --port [port]                frontend port
        --timeout [s]                timeout for requests (s)
    -t, --type [device type]         specify type
        --csv [file]                 write results in a csv file
    -v, --verbose                    verbose output
    -l, --log                        log http requests
```

#Result
The result of the test can be display on the screen or saved in a csv file with the --csv parameter. 

Output example (CSV)
```shell
type;server;instance;device;result
IBM LPAR;s6259b7a1;ibm-lpar;192.168.1.2;FAILED
IBM LPAR;s9c5f3e05;ibm-lpar;192.168.1.3;FAILED
IBM LPAR;s9c5f3e05;ibm-lpar;192.168.1.4;SUCCESS
IBM LPAR;s9c5f3e05;ibm-lpar;192.168.1.5;SUCCESS
IBM LPAR;s48e2574c;ibm-lpar;192.168.1.6;FAILED
Host configuration;s736293d4;Generic-RSC;192.168.1.7;FAILED
```

#Contributing
Create a fork of the project into your own reposity. Make all your necessary changes and create a pull request with a description on what was added or removed and details explaining the changes in lines of code. If approved, project owners will merge it.

#License
```
    Licensed under the Apache License, Version 2.0 (the "License"); you may
    not use this file except in compliance with the License. You may obtain
    a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
    License for the specific language governing permissions and limitations
    under the License.
```

#Support
Please file bugs and issues on the Github issues page for this project. This is to help keep track and document everything related to this repo. For general discussions and further support you can join the EMC {code} Community slack channel. Lastly, for questions asked on Stackoverflow.com please tag them with EMC. The code and documentation are released with no warranties or SLAs and are intended to be supported through a community driven process.
