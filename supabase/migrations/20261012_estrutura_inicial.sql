-- Personal Execution Tracker - schema inicial do ambiente de desenvolvimento
-- EXECUTAR SOMENTE EM UM PROJETO SUPABASE NOVO E VAZIO.
-- Estrutura consolidada dos scripts 01 a 06 compartilhados pelo usuário.
-- Não copia usuários nem dados do projeto de produção.

begin;

create table public.temporadas (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users(id) on delete cascade,
  numero integer not null check (numero > 0),
  nome text not null,
  objetivos text,
  atividades_planejadas text,
  prioridade text,
  criterios_sucesso text,
  data_inicio date not null,
  status text not null default 'ativa' check (status in ('ativa', 'encerrada')),
  resultados_obtidos text,
  desafios text,
  aprendizados text,
  proxima_temporada text,
  comprometimento integer check (comprometimento between 1 and 5),
  satisfacao integer check (satisfacao between 1 and 5),
  encerrada_em timestamptz,
  criada_em timestamptz not null default now(),
  objetivo_principal text,
  marcos_temporada jsonb not null default '[]'::jsonb,
  unique (usuario_id, numero)
);

create unique index temporadas_uma_ativa_por_usuario
  on public.temporadas (usuario_id) where status = 'ativa';

create table public.semanas (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references public.temporadas(id) on delete cascade,
  usuario_id uuid not null references auth.users(id) on delete cascade,
  numero integer not null check (numero between 1 and 8),
  data_inicio date not null,
  meta_pontos integer not null default 12 check (meta_pontos > 0),
  status text not null default 'aberta' check (status in ('aberta', 'encerrada')),
  funcionou_bem text,
  dificuldades text,
  ajuste_proxima_semana text,
  comprometimento integer check (comprometimento between 1 and 5),
  satisfacao integer check (satisfacao between 1 and 5),
  encerrada_em timestamptz,
  criada_em timestamptz not null default now(),
  revisao_resultados text,
  revisao_dificuldades text,
  revisao_aprendizados text,
  revisao_comprometimento integer check (revisao_comprometimento between 1 and 5),
  unique (temporada_id, numero)
);

create table public.atividades (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users(id) on delete cascade,
  semana_id uuid not null references public.semanas(id) on delete cascade,
  nome text not null,
  dia text not null check (dia in ('Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo')),
  icone text not null default '📌',
  concluida boolean not null default false,
  criada_em timestamptz not null default now(),
  concluida_em timestamptz
);

alter table public.temporadas enable row level security;
alter table public.semanas enable row level security;
alter table public.atividades enable row level security;

create policy "Usuarios consultam suas temporadas" on public.temporadas
  for select to authenticated using ((select auth.uid()) = usuario_id);
create policy "Usuarios criam suas temporadas" on public.temporadas
  for insert to authenticated with check ((select auth.uid()) = usuario_id);
create policy "Usuarios atualizam suas temporadas" on public.temporadas
  for update to authenticated using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

create policy "Usuarios consultam suas semanas" on public.semanas
  for select to authenticated using (
    (select auth.uid()) = usuario_id and exists (
      select 1 from public.temporadas t
      where t.id = temporada_id and t.usuario_id = (select auth.uid())
    )
  );
create policy "Usuarios criam suas semanas" on public.semanas
  for insert to authenticated with check (
    (select auth.uid()) = usuario_id and exists (
      select 1 from public.temporadas t
      where t.id = temporada_id and t.usuario_id = (select auth.uid())
    )
  );
create policy "Usuarios atualizam suas semanas" on public.semanas
  for update to authenticated using ((select auth.uid()) = usuario_id)
  with check (
    (select auth.uid()) = usuario_id and exists (
      select 1 from public.temporadas t
      where t.id = temporada_id and t.usuario_id = (select auth.uid())
    )
  );

create policy "Usuarios consultam suas atividades" on public.atividades
  for select to authenticated using (
    (select auth.uid()) = usuario_id and exists (
      select 1 from public.semanas s
      where s.id = semana_id and s.usuario_id = (select auth.uid())
    )
  );
create policy "Usuarios criam suas atividades" on public.atividades
  for insert to authenticated with check (
    (select auth.uid()) = usuario_id and exists (
      select 1 from public.semanas s
      where s.id = semana_id and s.usuario_id = (select auth.uid())
    )
  );
create policy "Usuarios atualizam suas atividades" on public.atividades
  for update to authenticated using ((select auth.uid()) = usuario_id)
  with check (
    (select auth.uid()) = usuario_id and exists (
      select 1 from public.semanas s
      where s.id = semana_id and s.usuario_id = (select auth.uid())
    )
  );
create policy "Usuarios excluem suas atividades" on public.atividades
  for delete to authenticated using ((select auth.uid()) = usuario_id);

create function public.criar_temporada(
  p_nome text,
  p_data_inicio date,
  p_objetivos text default '',
  p_atividades_planejadas text default '',
  p_prioridade text default '',
  p_criterios_sucesso text default ''
)
returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare
  v_usuario_id uuid;
  v_temporada_id uuid;
  v_numero integer;
begin
  v_usuario_id := (select auth.uid());
  if v_usuario_id is null then
    raise exception 'Usuário não autenticado.';
  end if;
  if nullif(trim(p_nome), '') is null then
    raise exception 'Informe o nome da temporada.';
  end if;
  if p_data_inicio is null then
    raise exception 'Informe a data de início.';
  end if;
  if exists (
    select 1 from public.temporadas
    where usuario_id = v_usuario_id and status = 'ativa'
  ) then
    raise exception 'Encerre a temporada atual antes de iniciar outra.';
  end if;
  select coalesce(max(numero), 0) + 1 into v_numero
  from public.temporadas where usuario_id = v_usuario_id;
  insert into public.temporadas (
    usuario_id, numero, nome, objetivos, atividades_planejadas,
    prioridade, criterios_sucesso, data_inicio, status
  ) values (
    v_usuario_id, v_numero, trim(p_nome), p_objetivos,
    p_atividades_planejadas, p_prioridade, p_criterios_sucesso,
    p_data_inicio, 'ativa'
  ) returning id into v_temporada_id;
  insert into public.semanas (
    usuario_id, temporada_id, numero, data_inicio, meta_pontos, status
  )
  select v_usuario_id, v_temporada_id, numero_semana,
    p_data_inicio + ((numero_semana - 1) * 7), 12, 'aberta'
  from generate_series(1, 8) as numero_semana;
  return v_temporada_id;
end;
$$;

revoke all on function public.criar_temporada(text, date, text, text, text, text) from public, anon;
grant execute on function public.criar_temporada(text, date, text, text, text, text) to authenticated;

create function public.proteger_semana_encerrada()
returns trigger language plpgsql security invoker set search_path = public
as $$
begin
  if old.status = 'encerrada' then
    raise exception 'Esta semana foi encerrada e não pode ser modificada.';
  end if;
  return new;
end;
$$;

create trigger trg_proteger_semana_encerrada
  before update or delete on public.semanas
  for each row execute function public.proteger_semana_encerrada();

create function public.proteger_atividade_semana_encerrada()
returns trigger language plpgsql security invoker set search_path = public
as $$
declare
  id_semana uuid;
  estado text;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    id_semana := old.semana_id;
    select status into estado from public.semanas where id = id_semana for update;
    if estado is distinct from 'aberta' then
      raise exception 'Atividades de semanas encerradas não podem ser alteradas.';
    end if;
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    id_semana := new.semana_id;
    select status into estado from public.semanas where id = id_semana for update;
    if estado is distinct from 'aberta' then
      raise exception 'Não é permitido adicionar ou mover atividades para semanas encerradas.';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger trg_proteger_atividade_semana_encerrada
  before insert or update or delete on public.atividades
  for each row execute function public.proteger_atividade_semana_encerrada();

commit;
