xquery version "3.1";

module namespace dts-client = "http://www.tei-c.org/tei-publisher/dts-client";

import module namespace custom-config = "http://www.tei-c.org/tei-simple/custom-config"
    at "../custom-config.xqm";

import module namespace http = "http://expath.org/ns/http-client"
    at "h";

import module namespace util = "http://exist-db.org/xquery/util";
import module namespace console = "http://exist-db.org/xquery/console";
import module namespace errors = "http://e-editiones.org/roaster/errors";


(: ping the DTS server to check its availability :)
declare function dts-client:ping() as item()* {
    try {
        let $url := $custom-config:dts-server
        let $request :=
            <http:request
                status-only="true"
                method="GET"
                href="{$url}"
                timeout="2"/>
        let $response := http:send-request($request)
        let $status := xs:integer($response[1]/@status)
        return $status ge 200 and $status lt 300
    } catch * {
        error($errors:SERVER_ERROR, "Failed to ping the DTS server. Please check the DTS endpoint URL.")
    }
};
(:~
 : Build the URL for a DTS collection request.
 :
 : An empty collection ID causes the configured root collection ID
 : to be used.
 :
 : @param $id    DTS collection identifier
 : @param $page  Page number, starting at 1
 : @param $limit Maximum number of members to return
 :)
declare function dts-client:collection-url(
    $id as xs:string?,
    $page as xs:integer,
    $limit as xs:integer
) as xs:anyURI {

    let $base-url :=
        $custom-config:dts-server || "/collection"

    let $query :=
        if (exists($id) and normalize-space($id) ne "")
        then
            "?id=" || encode-for-uri(normalize-space($id))
            || "&amp;page=" || $page
            || "&amp;limit=" || $limit
        else
            "?page=" || $page
            || "&amp;limit=" || $limit

    return
        xs:anyURI($base-url || $query)
};

(:~
 : Build the URL for a DTS resource request.
 :
 : @param $id    DTS resource identifier
 : @return The full URL to access the DTS resource
 :)
declare function dts-client:resource-url(
    $id as xs:string, $ref as xs:string?
) as xs:anyURI {

    let $base-url :=
        $custom-config:dts-server || "/document"

    let $query :=
        "?resource=" || encode-for-uri(normalize-space($id))
        || (if (exists($ref) and normalize-space($ref) ne "") then "&amp;ref=" || encode-for-uri(normalize-space($ref)) else "")

    return
        xs:anyURI($base-url || $query)
};

declare function dts-client:navigation-url(
    $id as xs:string,
    $ref as xs:string?,
    $down as xs:integer?
) as xs:anyURI {

    let $base-url :=
        $custom-config:dts-server || "/navigation"

    let $query :=
        "?resource=" || encode-for-uri(normalize-space($id))
        || (if (exists($ref) and normalize-space($ref) ne "") then "&amp;ref=" || encode-for-uri(normalize-space($ref)) else "")
        || (if (exists($down)) then "&amp;down=" || $down else "")

    return
        xs:anyURI($base-url || $query)
};

(:~
 :  Retrieve a DTS resource by its identifier.
 :
 : @param $id    DTS resource identifier
 : @param $ref   Optional reference for the DTS resource
 : @return The parsed DTS XML document as a document-node()
 :)
declare function dts-client:get-resource(
    $id as xs:string,
    $ref as xs:string?
) as document-node() {
    let $_ := console:log($id)
    let $_ := console:log($ref)
    let $url := dts-client:resource-url($id, $ref)
    let $_ := console:log($url)
    let $request :=
        <http:request
            method="GET"
            href="{$url}"
            override-media-type="application/xml"/>
    let $response := http:send-request($request)
    let $status := xs:integer($response[1]/@status)
    return
        if ($status ge 200 and $status lt 300) then
            (: the DTS resource content is already an XML document node it can be returned directly :)
            $response[2]
        else
            error(
                xs:QName("dts-client:HTTP-ERROR"),
                concat(
                    "DTS resource request failed with HTTP status ",
                    $status,
                    ": ",
                    $response[2]
                )
            )
};

declare function dts-client:get-navigation(
    $id as xs:string,
    $ref as xs:string?,
    $down as xs:integer?
) as map(*) {
    let $url := dts-client:navigation-url($id, $ref, $down)
    let $request :=
        <http:request
            method="GET"
            href="{$url}"
            override-media-type="application/json"/>
    let $response := http:send-request($request)
    let $json := parse-json(util:binary-to-string($response[2]))
    let $status := xs:integer($response[1]/@status)
    return
        if ($status ge 200 and $status lt 300) then
            $json
        else
            error(
                xs:QName("dts-client:HTTP-ERROR"),
                concat(
                    "DTS navigation request failed with HTTP status ",
                    $status,
                    ": ",
                    $response[2]
                )
            )
};
(: recurse member by member, stopping as soon as $id is matched :)
declare %private function dts-client:find-next(
    $members as array(*),
    $id as xs:string,
    $i as xs:integer,
    $size as xs:integer
) as map(*)? {
    if ($i gt $size) then
        ()
    else if ($members($i)?identifier = $id) then
        let $next := if ($i lt $size) then $members($i + 1) else ()
        return map {"nav": $next, "id": $members($i)?identifier}
    else
        dts-client:find-next($members, $id, $i + 1, $size)
};

(:~
 : Using the navigation structure this function will return the next members relative to the given $id.
~:)
declare function dts-client:get-next(
    $id as xs:string,
    $nav as map(*)
) {
    let $members := map:get($nav, "member")
    return dts-client:find-next($members, $id, 1, array:size($members))
};
(: recurse member by member, stopping as soon as $id is matched :)
declare %private function dts-client:find-previous(
    $members as array(*),
    $id as xs:string,
    $i as xs:integer,
    $size as xs:integer
) as map(*)? {
    if ($i gt $size) then
        ()
    else if ($members($i)?identifier = $id) then
        let $prev := if ($i gt 1) then $members($i - 1) else ()
        return map {"nav": $prev, "id": $members($i)?identifier}
    else
        dts-client:find-previous($members, $id, $i + 1, $size)
};

(:~
 : Using the navigation structure this function will return the previous members relative to the given $id.
~:)
declare function dts-client:get-previous(
    $id as xs:string,
    $nav as map(*)
) {
    let $members := map:get($nav, "member")
    return dts-client:find-previous($members, $id, 1, array:size($members))
};

(:~
 : Retrieve one page of members from a DTS collection.
 :
 : The DTS JSON response is parsed and returned as a map/array
 : structure (as produced by fn:parse-json). No further
 : transformation is performed by this client.
 :
 : If $id is empty, the collection configured as
 : $config:dts-root-collection is requested.
 :
 : @param $id    DTS collection identifier; empty means root collection
 : @param $page  Page number, starting at 1
 : @param $limit Maximum number of members to return
 :
 : @return The parsed DTS JSON response as a map
 :)
declare function dts-client:get-collection(
    $id as xs:string?,
    $page as xs:integer,
    $limit as xs:integer
) as map(*) {

    if ($page lt 1) then
        error(
            xs:QName("dts-client:INVALID-PAGE"),
            "The DTS page number must be greater than or equal to 1."
        )
    else if ($limit lt 1) then
        error(
            xs:QName("dts-client:INVALID-LIMIT"),
            "The DTS collection limit must be greater than or equal to 1."
        )
    else
        let $url :=
            dts-client:collection-url($id, $page, $limit)

        let $request :=
            <http:request
                method="GET"
                href="{$url}"
                override-media-type="application/json"/>

        let $response :=
            http:send-request($request)

        let $status :=
            xs:integer($response[1]/@status)

        let $body :=
            if ($response[2] instance of xs:base64Binary or $response[2] instance of xs:hexBinary)
            then
                util:binary-to-string($response[2])
            else
                string($response[2])

        return
            if ($status ge 200 and $status lt 300) then
                parse-json($body)
            else
                error(
                    xs:QName("dts-client:HTTP-ERROR"),
                    concat(
                        "DTS collection request failed with HTTP status ",
                        $status,
                        ": ",
                        $url
                    )
                )
};

(: filter out only the resources from a DTS collection :)
declare function dts-client:dts-resources($collection as map(*)) as array(*) {
    let $members := map:get($collection, "member")
    let $resources := array {
        $members?*[
            not(map:get(., "@type") = "resource")
        ]
    }

    return $resources
    
};