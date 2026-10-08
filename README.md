# DTS-MOD

Teipublisher profil that brings all dts components and features into your app.
This profil is helping users that who need strict separation of concern and quick data source switching.

This profil will replace the existdb retrieval logic. The "model" part of the architecture is replaced with remote server data.


### installation

Deploy the dts-mod folder in the jinks/profil folder. 

Add the ```dts-mod``` profile name into the jinks config file trough the apps/jinks iinterface or the jinks API.

**note:** run .existdb.json from vs code with the admin account first in order to open a connection to the existdb server and install the vscode applet. then switch to your account.

### properties 

Profile config (default settings) :

```json   
 "dts-mod": {
     "dts-endpoint": "http://host.docker.internal:8000/api/dts/v1/"
    },
    "api": [
        {
            "spec": "dts-api.json",
            "prefix": "dmod-vapi",
            "path": "dmod-view.xql",
            "id": "http://teipublisher.com/api/dmod-vapi"
        }
    ]
```

### todo

- add allow multiple source selection (remote, local)