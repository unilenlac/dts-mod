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
        "dts-endpoint": "http://host.docker.internal:8000/api/dts/v1/",
        "public-dts-endpoint": "http://localhost:8000/api/dts/v1/"
    },
    "script": {
        "custom": [
            "resources/scripts/metadata-panel.js",
            "resources/scripts/dmod-toggle.js",
            "resources/scripts/dmod-endpoint-infos.js"
        ]
    },
    "styles": [
        "resources/css/dts-elements.css"
    ],
    "templating": {
        "use": [
            "templates/metadata-panel.html"
        ]
    },
    "api": [
        {
            "spec": "dts-api.json",
            "prefix": "dmod-vapi",
            "path": "dmod-view.xql",
            "id": "http://teipublisher.com/api/dmod-vapi"
        }
    ],
    "depends": [
        "base10",
        "metadata-panel"
    ],
    "features": {
        "dts-mod": {
            "metadata-panel": {
                "enabled": true
            }
        }
    }
```

### custom components
the custom components provided here are not bundled with the pb-component library in order to avoid extra maintenance overhead.

#### dmod-endpoint-infos:
this web component allows you to add dts endpoint informations on you template

#### dmod-toggle
this web component allows you to add a toggle button in a 'option' if needed. for the moment there there is two toggle implemented. One for enbale/disable pb/cb's element, the other one is for hide the footnotes.

### todo

- enable separate full-text/facet search :
    - FTS and facet search are not available trough a DTS endpoint, there is a need to a segregation between the serach feature provided by existdb and the main teipublisher app that is fueled with DTS data. worfklow suggested. move the serach feature into another paart of the publication, create a copy of the database inside the running existdb database in order to leverage the index feature of existdb (lucene), use normaly the search feature on this part of the web app, enrich the result with dts references and use them to navigate to the corresponding published element on the main part of the app. the search workflow is would be globally the following one:
        send serach input -> app -- show hits -- > app -- find dts reference --> app -- build/generate template -> return html and results
    once the results are displayed, the user is able to navigate to the corresponding part of the edition with the dts metadata provided with the displayed results
    Also, the 'find dts reference' feature is already provided on the dts enpoint. the feature is available at the /find-reference route
