
You are an sap abap expert. you need to create a fiori application . you have a database yhr_job_switch. the database keeps a pernr, startdate, enddate, new_job_id, and several other info fields. The fiori app needs to have a modern sap look and feel. you work on a SAP S4hana system but not the latest. the 2023 version. I thought of using the FCL in fiori. some things to keep in mind. i would like to use filters and sorting on the 4 fields in the master view. in the detail i want to have some freedom on how i setup the fields. I have some experience with fiori but never used fiori elements. as I understand good with fiori elements you can have filters and sorting out of the box. I dont know how to give annotations to my yhr_job_switch table.  what is your advice? use a fiori elements for the master and freestyle for the detail?  ask me some questions if needed and consult/advice me how i can achieve this.

Recommendation: Fiori Elements List Report + Object Page (LROP), not FCL + freestyle
The good news: you don't need to build FCL yourself. The standard Fiori Elements "List Report – Object Page" (LROP) floorplan is a Flexible Column Layout app out of the box — master list on the left, detail opens in a column next to it, drills further right on demand. That's exactly the FCL behavior you're picturing, and Fiori Elements gives it to you for free, along with filtering/sorting on the master.

So the pattern is:

Master (List Report): filters + sorting on your 4 fields → comes free from annotations, zero JS.
Detail (Object Page): you have more layout freedom than you might think via annotations (facets, sections, field groups, tables) — and if you truly need pixel-level custom layout for part of the page, you can drop a custom section (an XML fragment you write by hand) into an otherwise-standard Object Page. That gives you a hybrid: 90% generated, with an escape hatch exactly where you need control — without abandoning Fiori Elements or hand-rolling FCL/routing.
I'd only reach for a fully freestyle detail view glued into FCL manually if the custom section escape hatch genuinely isn't enough (e.g. a highly interactive custom canvas, not just "arrange fields differently").

How annotations work for YHR_JOB_SWITCH
Since this is a custom table (Y-namespace), the flow is:

CDS View Entity on top of YHR_JOB_SWITCH (in Eclipse/ADT) — this becomes your OData-exposed entity.
UI annotations — don't put them inline in the CDS view. Use a Metadata Extension (@Metadata.layer: #CORE, separate .ddlx file). This is the S/4HANA-recommended pattern: it keeps the data-modeling CDS clean and lets you (or a UI dev) evolve the UI independently. Key annotations you'll actually use:
@UI.selectionField on the 4 filter fields (with position to control filter bar order)
@UI.lineItem on master table columns (sortable by default)
@UI.facet (+ @UI.fieldGroup / @UI.identification) to lay out the Object Page sections
@UI.presentationVariant for default sort order on the master
Service exposure: for S/4HANA 2023 (on-prem, ABAP Platform 2022-based), I'd default to RAP (RESTful ABAP Programming Model) with an OData V4 service — it's SAP's current recommended path and plays best with Fiori Elements v4 floorplans/annotations, cleaner than classic SEGW. This matters a lot for your architecture, hence the questions below.
A few things I need from you before locking this in
Is the app read-only (just displaying/reporting job switches) or does it need to create/edit/delete records too?

Full create/edit/delete

What's your ABAP development tooling access?

Eclipse ADT + BAS (Recommended)

How much custom freedom do you actually need on the detail page?

Largely custom interactive layout

Given full CRUD + custom interactive detail layout, here's the concrete architecture:

Recommended stack
List Report (master) → Custom Page (detail), one Fiori Elements app, Flexible Programming Model

This is a named, SAP-supported pattern (not a workaround): you generate a standard Fiori Elements List Report app, then swap only the Object Page route for your own freestyle view/controller. You get:

Filters + sorting on your 4 fields: 100% free from annotations, no code
FCL behavior (master列 → detail column → optional further drill-down): handled by the FE app shell, you write zero routing/layout code
Detail page: fully your own XML views, controllers, fragments — real freestyle SAPUI5, just slotted into the FE app instead of a separate app
You get exactly the split you originally asked about, but wired together properly instead of you gluing two apps into FCL by hand.

Backend: Managed RAP Business Object (non-draft)
Since you need create/edit/delete, I'd start with non-draft managed RAP rather than draft:

Draft (SAP's default recommendation for FE) buys you "save incomplete, resume later" UX, but it forces you to orchestrate draft/activate/discard actions from your custom-page code too — real complexity for a hand-written detail view.
Non-draft managed RAP still gives you generated CRUD, standard OData V4 CREATE/UPDATE/DELETE, ETag-based concurrency handling — you just call it directly from your custom controller like any REST-ish V4 model operation. Much simpler to code against freely.
You can add draft later if HR actually needs "save as draft" — it's an incremental change to the behavior definition, not a rewrite.
Concrete build steps (ADT + BAS)
ADT: CDS view entity on YHR_JOB_SWITCH → root view for a Managed RAP BO.
ADT: Behavior Definition (managed, non-draft) with create, update, delete — plus a Behavior Implementation class only if you need validations/determinations (e.g. enddate > startdate).
ADT: Metadata Extension (.ddlx) with @UI.selectionField (4 filter fields), @UI.lineItem (master columns), @UI.presentationVariant (default sort) — Object Page facet annotations here are optional/minimal since detail is custom.
ADT: Service Definition + Service Binding (OData V4, UI), publish and test in the built-in preview.
BAS: Fiori Application Generator → "List Report Page" (or "List Report Object Page" then strip it down) using that V4 service.
BAS: In manifest.json, change the Object Page route's target from the generated sap.fe.templates.ObjectPage component to your own custom view (type: "Component" pointing at a component, or a plain custom view per the flexible-programming-model extension point) — this is where your freestyle detail page plugs in.
Build the custom detail view against the same V4 ODataModel instance the FE app already has bound — reuse it rather than creating a second model.
One thing worth deciding before I go further: do you want me to sketch the actual CDS/behavior-definition code and the manifest.json routing change next, or would it help more to first talk through the field list/validations you need on YHR_JOB_SWITCH (the "several other info fields" you mentioned)?

i need 2 custom filters and 2 standard filters. also my crud operations should not be managed i think.  cause my save should not only do a save in yhr_job_switch. other stuff should happen aswell.

Good — both of those push this toward more hand-written code, which is fine, RAP supports it cleanly.

Unmanaged RAP for the save
Switch the Behavior Definition to unmanaged (define behavior for ... implementation in class zbp_.../unmanaged). Instead of the framework doing INSERT/UPDATE/DELETE for you, you implement it yourself in the behavior pool class:

create, update, delete methods — you write the actual MODIFY/INSERT on yhr_job_switch yourself, plus whatever else needs to happen (call a BAPI, write to other Z/Y tables, trigger a workflow, send a notification...).
The save sequence gives you explicit hooks: finalize → check_before_save → save → cleanup. Your "other stuff" typically belongs in save (same LUW, same COMMIT boundary as the table update — so if the extra logic fails, the whole transaction rolls back together, which is what you want for consistency).
You still get standard RAP lock handling (lock master), authorization checks, and OData V4 exposure for free — "unmanaged" only means you own the persistence/side-effect logic, not that you lose the RAP integration with Fiori Elements.
This is exactly the right tool for "save does more than persist one table" — don't force managed RAP with determinations/validations bolted on; unmanaged is cleaner once the save has real side effects.

One thing to pin down on the filters before I sketch the CDS/manifest side:

What makes the 2 "custom" filters custom — different from the 2 standard ones?

Filter doesn't map to one persisted field

Two ways to handle a filter that doesn't map to a raw column, in order of preference:

Preferred: CDS calculated element (still fully annotation-driven)
If the filter logic can be expressed as SQL (a CASE, date arithmetic, a comparison against $session.system_date, a CAST, etc.), add it as a calculated element directly in the CDS view:

case
  when enddate between $session.system_date and $session.system_date + 30
  then 'X' else ' '
end as EndingSoon
Mark it @UI.selectionField + @Consumption.filter like any other field. From the Fiori Elements app's point of view this is a completely standard filter — generated FilterBar, no fragments, no JS event handlers. This is the right answer for things like "ending within 30 days," a derived status, a combined condition across startdate/enddate, etc. Always try this first.

Fallback: true custom filter field + custom query logic
Only needed if the condition genuinely can't be expressed in SQL (external data, complex ABAP-only business rules). That means:

A manifest-level custom filter field (filterFields with type: "Custom", pointing at your own XML fragment control)
A JS event handler that translates the control's value into a $filter condition on the request
On the backend, a custom RAP query provider (IF_RAP_QUERY_PROVIDER) on that CDS view to interpret filter conditions the standard OData-to-SQL translation can't handle
This path is real work — a custom query handler class, not just annotations — so it's worth avoiding unless truly necessary.

Can you tell me in plain terms what the two custom filters actually filter on? If either one is expressible as "some comparison/derivation of fields already on the table" (dates, status flags, ranges), it very likely belongs in the calculated-element path and we can skip the custom query provider entirely.



