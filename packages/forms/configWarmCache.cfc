component displayName="Cache Warming" hint="Tools for pre-emptively inserting content into the Object Broker" key="warmcache" extends="farcry.core.packages.forms.forms" {

    property name="statsID" type="string" ftDefault="##application.applicationname##" ftDefaultType="expression"
             ftSeq="1" ftFieldSet="Cache Warming" ftLabel="Statistics ID"
             ftHint="The identifier to log statistics under";

    property name="threads" type="numeric" ftDefault="2"
             ftSeq="2" ftFieldSet="Cache Warming" ftLabel="Threads"
             ftType="integer"
             ftHint="Maximum number of threads for warming";

    property name="standardStrategy" type="string"
             ftSeq="3" ftFieldSet="Cache Warming" ftLabel="Strategy"
             ftHint="Standard warming strategy.";

}