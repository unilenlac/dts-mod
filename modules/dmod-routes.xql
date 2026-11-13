xquery version "3.1";

(:~
 : This is the place to import your own XQuery modules for either:
 :
 : 1. custom API request handling functions
 : 2. custom templating functions to be called from one of the HTML templates
 :)
module namespace dmod="http://teipublisher.com/api/dmod";

declare namespace tei="http://www.tei-c.org/ns/1.0";
(: Add your own module imports here :)
import module namespace rutil="http://e-editiones.org/roaster/util";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace cutil="http://teipublisher.com/api/cache" at "./lib/api/caching.xql";
import module namespace json="http://www.json.org";
import module namespace console="http://exist-db.org/xquery/console";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace capi="http://teipublisher.com/api/collection" at "./lib/api/collection.xql";
import module namespace router="http://e-editiones.org/roaster";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace vapi="http://teipublisher.com/api/view" at "view.xql";
import module namespace dts-client="http://www.tei-c.org/tei-publisher/dts-client" at "./dts-mod/dts-client.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "../lib/util.xql";
import module namespace page="http://teipublisher.com/ns/templates/page" at "../../templates/page.xqm";

(:~
 : Keep this. This function does the actual lookup in the imported modules.
 :)
declare function dmod:lookup($name as xs:string, $arity as xs:integer) {
    try {
        function-lookup(xs:QName($name), $arity)
    } catch * {
        ()
    }
};


(:~
: Retrieve information about the available endpoints in the dts-mod module
: @param $request a map representing the API request
: @param $ref an optional reference to be included in the rendered HTML
: @return a rendered HTML representing the endpoint information combined with the 'ref' parameter value, if provided
:)
declare function dmod:endpoint-infos($request as map(*)) as node()* {
    let $resource := normalize-space($request?parameters?resource)
    let $ref := normalize-space($request?parameters?ref)
    let $templatePath := "/templates/components/dts-metadata-panel.html"
    (: public-dts-server ends with a slash :)
    let $documentLink :=
        if ($resource ne "") then
            $config:public-dts-server || "document/?resource=" || encode-for-uri($resource)
        else ""
    let $excerptLink :=
        if ($documentLink ne "" and $ref ne "") then
            $documentLink || "&amp;ref=" || encode-for-uri($ref)
        else ""
    let $model := map:merge((
        vapi:load-config-json($request),
        map {
            "server-link": $config:public-dts-server,
            "document-link": $documentLink,
            "excerpt-link": $excerptLink
        }
    ))
    return
        if (doc-available($config:app-root || $templatePath)) then
            tmpl:process(serialize(config:resolve($templatePath)), $model, map {
                "plainText": false(),
                "resolver": vapi:resolver#1,
                "modules": map {
                    "http://www.tei-c.org/tei-simple/config": map {
                        "prefix": "config",
                        "at": "modules/config.xqm"
                    }
                }
            })
        else
            <div>Template not available</div>
};