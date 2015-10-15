#mnrdiscovery
```mnrdiscovery``` is a CLI to test devices accessibility from EMC SRM and other M&R products.

#Usage
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

#Contributing
fork it, use it, break it, fix it, upgrade it...

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
