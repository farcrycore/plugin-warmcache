component displayName="Cache Warming" hint="Tools for pre-emptively inserting content into the Object Broker" key="warmcache" extends="farcry.core.packages.forms.forms" {

    property name="threads" type="numeric" ftDefault="2"
             ftSeq="1" ftFieldSet="Cache Warming" ftLabel="Threads"
             ftType="integer"
             ftHint="Maximum number of threads for warming";

    property name="standardStrategy" type="string"
             ftSeq="2" ftFieldSet="Cache Warming" ftLabel="Strategy"
             ftHint="Standard warming strategy.";

}