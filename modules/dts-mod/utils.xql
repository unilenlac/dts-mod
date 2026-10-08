xquery version "3.1";

module namespace dmod-util="http://www.ftsr.unil.ch/dts-mod/utils";

import module namespace console="http://exist-db.org/xquery/console";

declare function dmod-util:toc-entry($context as map(*), $content as node()?, $collapse as xs:boolean?) {
    if ($context?subNav) then
        <details>
            {
                if (not($collapse)) then
                    attribute open { "open" }
                else
                    ()
            }
            <summary>
            {
                <pb-link xml-id="{$context?docId}" emit="{$context?target}" subscribe="{$context?target}">{$context?label}</pb-link>
            }
            </summary>
            { $content }
        </details>
    else <pb-link xml-id="{$context?docId}" emit="{$context?target}" subscribe="{$context?target}">{$context?label}</pb-link>
};