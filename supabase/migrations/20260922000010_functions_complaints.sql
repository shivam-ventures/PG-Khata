-- PG Khata — migration 10/12: complaint lifecycle as Postgres functions.
--
-- Same pattern as migration 9: every write to complaints/complaint_events
-- happens through one of these (RLS in migration 12 grants SELECT only on
-- both tables to authenticated roles).

alter table complaints add column idempotency_key text;
create unique index complaints_idempotency_key_idx on complaints (idempotency_key) where idempotency_key is not null;

comment on column complaints.idempotency_key is
  'Client-generated, resent on retry — see docs/backend-domain-model.md §11/§26 (duplicate-tap/retry safety for report_complaint).';

create or replace function tenant_owns_complaint(target_complaint_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from complaints c
    join tenancies t on t.id = c.tenancy_id
    where c.id = target_complaint_id and t.profile_id = auth.uid()
  );
$$;

create or replace function report_complaint(
  p_property_id uuid,
  p_tenancy_id uuid,       -- null for a common-area complaint, reported by staff
  p_category text,
  p_severity text,
  p_title text,
  p_room_label text,
  p_time_preference text,
  p_idempotency_key text default null
)
returns complaints
language plpgsql
security definer
set search_path = public
as $$
declare
  v_complaint complaints;
  v_authorized boolean;
begin
  if p_tenancy_id is not null then
    select exists (select 1 from tenancies where id = p_tenancy_id and profile_id = auth.uid())
      into v_authorized;
  else
    v_authorized := is_staff_for_property(p_property_id);
  end if;
  if not v_authorized then
    raise exception 'not authorized to report this complaint';
  end if;

  if p_idempotency_key is not null then
    select * into v_complaint from complaints where idempotency_key = p_idempotency_key;
    if found then
      return v_complaint;
    end if;
  end if;

  insert into complaints (
    property_id, tenancy_id, category, severity, title, room_label,
    time_preference, reported_by, idempotency_key
  )
  values (
    p_property_id, p_tenancy_id, p_category, p_severity,
    coalesce(nullif(trim(p_title), ''), initcap(p_category) || ' issue'), -- matches MockComplaintsRepository's own fallback title
    p_room_label, p_time_preference, auth.uid(), p_idempotency_key
  )
  returning * into v_complaint;

  insert into complaint_events (complaint_id, event_type, actor_user_id)
  values (v_complaint.id, 'reported', auth.uid());

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_complaint.org_id, 'complaint.reported', 'complaint', v_complaint.id,
          jsonb_build_object('category', p_category, 'severity', p_severity));

  return v_complaint;
end;
$$;

-- Also covers the "Reassign" escape hatch on an already-delegated/resolved
-- complaint — it's just another delegated event with a new assignee, so
-- who was assigned before is preserved in complaint_events, unlike the
-- mock's in-place overwrite.
create or replace function delegate_complaint(
  p_complaint_id uuid,
  p_assignee text,
  p_note text default null
)
returns complaints
language plpgsql
security definer
set search_path = public
as $$
declare
  v_property_id uuid;
  v_complaint complaints;
begin
  select property_id into v_property_id from complaints where id = p_complaint_id;
  if v_property_id is null then
    raise exception 'complaint % not found', p_complaint_id;
  end if;
  if not is_staff_for_property(v_property_id) then
    raise exception 'not authorized to delegate this complaint';
  end if;
  if p_assignee is null or length(trim(p_assignee)) = 0 then
    raise exception 'an assignee is required';
  end if;

  insert into complaint_events (complaint_id, event_type, actor_user_id, assignee, note)
  values (p_complaint_id, 'delegated', auth.uid(), p_assignee, p_note);

  select * into v_complaint from complaints where id = p_complaint_id;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_complaint.org_id, 'complaint.delegated', 'complaint', v_complaint.id,
          jsonb_build_object('assignee', p_assignee, 'note', p_note));

  return v_complaint;
end;
$$;

create or replace function resolve_complaint(p_complaint_id uuid)
returns complaints
language plpgsql
security definer
set search_path = public
as $$
declare
  v_property_id uuid;
  v_complaint complaints;
begin
  select property_id into v_property_id from complaints where id = p_complaint_id;
  if v_property_id is null then
    raise exception 'complaint % not found', p_complaint_id;
  end if;
  if not is_staff_for_property(v_property_id) then
    raise exception 'not authorized to resolve this complaint';
  end if;

  insert into complaint_events (complaint_id, event_type, actor_user_id)
  values (p_complaint_id, 'resolved', auth.uid());

  select * into v_complaint from complaints where id = p_complaint_id;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_complaint.org_id, 'complaint.resolved', 'complaint', v_complaint.id, '{}');

  return v_complaint;
end;
$$;

-- The tenant's own "still not fixed?" action, or staff correcting a
-- wrongly-closed common-area complaint.
create or replace function reopen_complaint(p_complaint_id uuid, p_note text default null)
returns complaints
language plpgsql
security definer
set search_path = public
as $$
declare
  v_property_id uuid;
  v_complaint complaints;
  v_authorized boolean;
begin
  select property_id into v_property_id from complaints where id = p_complaint_id;
  if v_property_id is null then
    raise exception 'complaint % not found', p_complaint_id;
  end if;

  v_authorized := tenant_owns_complaint(p_complaint_id) or is_staff_for_property(v_property_id);
  if not v_authorized then
    raise exception 'not authorized to reopen this complaint';
  end if;

  insert into complaint_events (complaint_id, event_type, actor_user_id, note)
  values (p_complaint_id, 'reopened', auth.uid(), p_note);

  select * into v_complaint from complaints where id = p_complaint_id;

  insert into audit_log (actor_user_id, org_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), v_complaint.org_id, 'complaint.reopened', 'complaint', v_complaint.id, '{}');

  return v_complaint;
end;
$$;
