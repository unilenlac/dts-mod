xquery version "3.1";

module namespace dts-client = "http://www.tei-c.org/tei-publisher/dts-client";

import module namespace custom-config = "http://www.tei-c.org/tei-simple/custom-config"
    at "../custom-config.xqm";

import module namespace http = "http://expath.org/ns/http-client"
    at "java:org.exist.xquery.modules.httpclient.HTTPClientModule";

import module namespace util = "http://exist-db.org/xquery/util";
import module namespace console="http://exist-db.org/xquery/console";


(: ping the DTS server to check its availability :)
declare function dts-client:ping() as item()* {
    try {
        let $url := $custom-config:dts-server
        let $request :=
            <http:request
                method="GET"
                href="{$url}"
                timeout="2"/>
        let $response := http:send-request($request)
        let $status := xs:integer($response[1]/@status)
        return $status ge 200 and $status lt 300
    } catch * {
        map {
            'code': string($err:code),
            'description': $err:description,
            'line-number': $err:line-number,
            'column-number': $err:column-number
        }
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