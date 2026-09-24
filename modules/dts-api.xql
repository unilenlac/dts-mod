xquery version "3.1";

(:~
 : This is the place to import your own XQuery modules for either:
 :
 : 1. custom API request handling functions
 : 2. custom templating functions to be called from one of the HTML templates
 :)
module namespace dmodapi="http://teipublisher.com/api/dmodapi";

declare namespace tei="http://www.tei-c.org/ns/1.0";
(: Add your own module imports here :)
import module namespace rutil="http://e-editiones.org/roaster/util";
(: import module namespace app="teipublisher.com/app" at "app.xql";:)
import module namespace config = "http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace custom-config = "http://www.tei-c.org/tei-simple/custom-config" at "./custom-config.xqm";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "./lib/pages.xql";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace cutil="http://teipublisher.com/api/cache" at "./lib/api/caching.xql";
import module namespace capi="http://teipublisher.com/api/collection" at "./lib/api/collection.xql";
import module namespace json="http://www.json.org";
import module namespace console="http://exist-db.org/xquery/console";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace router="http://e-editiones.org/roaster";
import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace vapi="http://teipublisher.com/api/view" at "view.xql";
import module namespace dts-client="http://www.tei-c.org/tei-publisher/dts-client" at "./dts-mod/dts-client.xql";
(:~
 : Keep this. This function does the actual lookup in the imported modules.
 :)
declare function dmodapi:lookup($name as xs:string, $arity as xs:integer) {
    try {
        function-lookup(xs:QName($name), $arity)
    } catch * {
        ()
    }
};

(:~
 : Example of a custom API function.
 : This one generates a table of contents based on milestones or divs.
 :
 : @param $request a map representing the API request
 : @return a JSON string representing the table of contents
 :)

declare function dmodapi:table-of-contents($request as map(*)) as node() {
    
};

declare function dmodapi:list($request as map(*)) {
    (: todo create a fallback in case the DTS is not available. the fallback will redirect to the capi:list function :)
    
    let $collection := if (map:contains($request?parameters, "collection")) then $request?parameters?collection else ()
    
    (: check if the DTS endpoint is available :)
    
    let $status := serialize(dts-client:ping(), map { "method": "json" })
    return if ($status = "true") then (
        dmodapi:list-dts($request)
     ) else (
        $status
    )
    

        (:
    return (
        console:log($request?parameters),
        console:log($collection),
        if ($dts) then (
            dmodapi:list-dts($request)
        )
        else (
            capi:list($request)
        )
    )
    :)
};
    
declare function dmodapi:list-dts($request as map(*)) as element(div) {
    
    let $path := $request?parameters?path
    let $per-page := $request?parameters?per-page
    let $start :=
        xs:integer(
            head((
                $request?parameters?start,
                1
            ))
        )

    let $page :=
        (($start - 1) idiv $per-page) + 1

    let $collection-id :=
        if (exists($path) and normalize-space($path) ne "")
        then $path
        else ()

    let $collection :=
        dts-client:get-collection(
            $collection-id,
            $page,
            $per-page
        )
    (: let $works :=
        dts-client:dts-resources($collection) :)
    let $works := map:get($collection, "member")
    let $total :=
        if (exists($collection?totalChildren))
        then xs:integer($collection?totalChildren)
        else count($works)

    let $full_path := $config:app-root || $custom-config:template_path
    let $template := config:resolve($custom-config:template_path) => serialize()
    let $context := map {
        "title": "My app",
        "data": $works
    }
    return (
        console:log($full_path),
        response:set-header(
            "pb-start",
            xs:string($start)
        ),
        response:set-header(
            "pb-total",
            xs:string($total)
        ),
        if (doc-available($full_path))
        then tmpl:process($template, $context, map { 
            "plainText": false(),
            "resolver": vapi:resolver#1,
                "modules": map {
                    "http://www.tei-c.org/tei-simple/custom-config": map {
                        "prefix": "custom-config",
                        "at": "modules/custom-config.xqm"
                    },
                    "http://www.tei-c.org/tei-simple/config": map {
                        "prefix": "config",
                        "at": "modules/config.xqm"
                    }
                }
            })
        else <div>Template not available</div>
        
        )
};