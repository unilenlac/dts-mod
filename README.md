# DTS-MOD

Teipublisher profil that brings all the dts components and features into your app.
This profil is helping users who need strict separation of concern and quick data source switching.

This profil will replace the existdb retrieval logic. The "model" part of the architecture is replaced with remote server data, except for the research feature.

## installation

Deploy the dts-mod folder in the `/apps/jinks/profil` folder.

enable the `dts-mod` profile trough the jinks config file in the apps/jinks iinterface or the jinks API.

**note:** for developer, run .the existdb.json config file from vs code with the admin account, in order to open a connection to the existdb server and install the vscode applet. Then switch the user credentials into the existdb config file in order to edit the module in vscode. This must be done only once the first time.

### properties

Profile config (default settings) :

```json
"dts-mod": {
        "dts-endpoint": "http://host.docker.internal:8000/api/dts/v1/",
        "public-dts-endpoint": "http://localhost:8000/api/dts/v1/",
        "resource-identifier": {
            "element": {
                "namespace": "http://www.tei-c.org/ns/1.0",
                "name": "TEI"
            },
            "source": "document-name"
        }
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
            "spec": "dmod-routes.json",
            "prefix": "dmod",
            "path": "dmod.xql",
            "id": "http://teipublisher.com/api/dmod"
        }
    ],
    "defaults": {
        "data": "/db/apps/tmpapp-data/data",
        "data-exclude": [
        "collection($config:data-root)//tei:TEI[not(tei:teiHeader/tei:revisionDesc/@status = 'published')]"
        ]
    },
    "menu": {
        "search": false,
        "items": [
            {
            "url": "search.html",
            "id": "Search"
            }
        ]
    },
    "features": {
        "toc": {
            "collapse": true,
            "enabled": true
        },
        "dts-mod": {
        "metadata-panel": {
            "enabled": true
        }
    }
    },
    "theme": {
        "layout": {
            "before": {
                "hidden": true
            }
        }
    },
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

## custom web-components

the custom components provided here are not bundled with the pb-component library in order to avoid extra maintenance overhead. the components are located inside the /resources/scripts folder.

#### \<dmod-endpoint-infos>

this web component allows you to add dts endpoint informations on you template

#### \<dmod-toggle>

this web component allows you to add a toggle button in a 'option' if needed. for now, there is two toggles inserted in the default metadata-pannel.html page. One for enbale/disable pb/cb's element, the other one to hide the footnotes.

## note about data storage

dmod is using a dts endpoint to retrieve text content based on citation references. the requests will provide text content, navigation or metadata values based on what the endpoint can provide and what is inside the running data storage behind the dts enpoint.

In a perfect world, the datastore that is behind the dts endpoint is the existdb database that is behind your teipublisher web app.

But you can also have a non existdb database behind your dts endpoint. In this case xml files must also be stored inside the existdb underneath the teipublisher app. This is what you should do, if you want to use the index/search features provided by existdb (lucene) and the dts-mod module.

This is comming with one caveat. the data stored inside the existdb can differ from what is actually served by the dts endpoint. this divergence can be mitigated differently. at the TPUB/Jinks level you can use an exclude filter in order to sync the existdb data source and the dts enpoint.

in this example, we exclude the unpublished files from the local database:

```
  "defaults": {
    "data": "/db/apps/webapp-data/data",
    "data-exclude": [
      "collection($config:data-root)//tei:TEI[not(tei:teiHeader/tei:revisionDesc/@status = 'published')]"
    ],
    "odd": "webapp.odd"
  },
```

## note about the search feature

teh ersearch feature is retrieving data from the local existdb and the remote dts endpoint. In order to havec the search feature running correctly there is two conditions :

1. you must have a running dts endpoint
2. your dts endpoint must implement a reverse reference finding feature. the schema must be declared like bellow.

```
"/api/dts/v1/document/find-reference":{
   "post":{
      "tags":[
         "document"
      ],
      "summary":"Find Fragment Reference",
      "description":"Find a document reference from an XML fragment",
      "operationId":"find_fragment_reference_api_dts_v1_document_find_reference_post",
      "parameters":[
         {
            "name":"resource",
            "in":"query",
            "required":true,
            "schema":{
               "type":"string",
               "title":"Resource"
            }
         },
         {
            "name":"ns",
            "in":"query",
            "required":false,
            "schema":{
               "anyOf":[
                  {
                     "type":"string"
                  },
                  {
                     "type":"null"
                  }
               ],
               "title":"Ns"
            }
         }
      ],
      "requestBody":{
         "required":true,
         "content":{
            "application/xml":{
               "schema":{
                  "type":"string",
                  "format":"binary",
                  "title":"Fragment"
               }
            }
         }
      },
      "responses":{
         "200":{
            "description":"Successful Response",
            "content":{
               "application/json":{
                  "schema":{
                     
                  }
               }
            }
         },
         "422":{
            "description":"Validation Error",
            "content":{
               "application/json":{
                  "schema":{
                     "$ref":"#/components/schemas/HTTPValidationError"
                  }
               }
            }
         }
      }
   }
}
```

dts-dmod will then have a route to submit an xml element and return the dts correspondig dts citation reference.

If you don't want to use this feature feel free to exclude the search.html page from you app.

**reminder** the find-reference feature is included inside the [pydts]("https://github.com/rerouj/py-dts") implementation of the DTS specifications.

### todos

- improve search feature
- ~~enable separate full-text/facet search~~ :
    - FTS and facet search are not available trough a DTS endpoint, there is a need to a segregation between the serach feature provided by existdb and the main teipublisher app that is fueled with DTS data. worfklow suggested. move the serach feature into another paart of the publication, create a copy of the database inside the running existdb database in order to leverage the index feature of existdb (lucene), use normaly the search feature on this part of the web app, enrich the result with dts references and use them to navigate to the corresponding published element on the main part of the app. the search workflow is would be globally the following one:
        send serach input -> app -- show hits -- > app -- find dts reference --> app -- build/generate template -> return html and results
    once the results are displayed, the user is able to navigate to the corresponding part of the edition with the dts metadata provided with the displayed results
    Also, the 'find dts reference' feature is already provided on the dts enpoint. the feature is available at the /find-reference route
```
