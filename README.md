# DTS-MOD

Teipublisher profil that brings all dts components and features into your app.
This profil is helping users that who need strict separation of concern and quick data source switching.

### installation

Use jinks with the ```dts-mod``` profile name
depends on the ```base-10```profil

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