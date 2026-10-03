# Hyze — guia do workspace (Claude no VS Code e Claude no Cowork)

Esta pasta (`Documents\Desenvolvimentos\hyze`) reúne **um repositório por empresa do grupo**,
todos na organização GitHub **`hyzecompany`**. Leia este guia antes de qualquer tarefa; cada
repositório tem também o seu `CLAUDE.md` com detalhes específicos.

## 1. Repositórios

| Pasta / repo       | O que é                                                                       | Publicado em                      |
| ------------------ | ----------------------------------------------------------------------------- | --------------------------------- |
| `hyze-ui`          | Design system: tokens, Poppins, logo, layout, formulário, animações, tsconfig | pacote `@hyze/ui` (tags `vX.Y.Z`) |
| `hyze-hub`         | Site do grupo + política de privacidade                                       | `hyzecompany.com.br`              |
| `hyze-sites`       | Hyze Sites — criação de sites                                                 | `sites.hyzecompany.com.br`        |
| `hyze-consultoria` | Hyze Consultoria — consultoria e suporte em TI                                | `consultoria.hyzecompany.com.br`  |
| `hyze-leads-api`   | API dos formulários (Hono + D1 + Turnstile)                                   | `api.hyzecompany.com.br`          |
| `.github`          | Perfil da organização + workflows de CI/CD reutilizáveis                      | —                                 |

Os sites consomem o design system como dependência git com versão:
`"@hyze/ui": "github:hyzecompany/hyze-ui#semver:^0.1.0"`.

## 2. Trabalho em dupla (OBRIGATÓRIO)

Dois agentes editam estas pastas: **Claude no VS Code** (local) e **Claude no Cowork**
(remoto, pela mesma pasta). Nenhum é notificado do que o outro fez — a sincronização é por
**disco + git + `docs/HANDOFF.md` de cada repositório**.

- **Ao começar:** rode `.\status.ps1` (Windows) ou `bash status.sh` para ver, em todos os repos,
  alterações pendentes e últimos commits. Leia o `docs/HANDOFF.md` dos repos que vai tocar.
  Alterações não commitadas que não são suas: **não sobrescreva** — pergunte ao Gabriel.
- **Durante:** commits pequenos, em português, Conventional Commits, com o trailer
  `Agente: vscode` ou `Agente: cowork`. Nada de `push --force`, `reset --hard` ou rebase sem pedido.
- **Ao terminar:** rode `pnpm lint && pnpm check && pnpm build` (e `pnpm test` na API) no repo
  alterado, registre uma entrada no topo do `docs/HANDOFF.md` dele, commite e faça `git push`.
  Nunca termine com a árvore suja.
- O Claude do Cowork não tem as credenciais do GitHub: **quem faz `git push` é o Claude do VS Code**
  (ou o Gabriel). O Cowork commita localmente e avisa no HANDOFF que falta o push.

## 3. Mudando o design system (hyze-ui)

1. Altere em `hyze-ui`, teste no catálogo (`pnpm dev` dentro de `hyze-ui`).
2. Para testar num site antes de publicar: no site, `pnpm link ../hyze-ui`; ao terminar,
   `pnpm install` de novo para voltar à versão do GitHub (não commite o link).
3. Suba a versão em `hyze-ui/package.json` (semver), commite, crie a tag `vX.Y.Z` e faça push
   da tag. Mudança que quebra compatibilidade = versão major.
4. Nos sites: `pnpm update @hyze/ui` (ou aceite o PR do Renovate), commite o lockfile.

## 4. Nova empresa do grupo

1. Em `hyze-ui/src/brands.ts`, ative/adicione a marca → nova versão do hyze-ui.
2. Copie `hyze-sites` para `hyze-<slug>`, ajuste `package.json`, `astro.config.mjs` (`site`),
   `wrangler.jsonc` (`name` e domínio), `brandLabel` e o conteúdo em `src/content.ts`.
3. Use `<LeadForm brand="<slug>" … />` — os leads caem na mesma API.
4. Crie o repo: `gh repo create hyzecompany/hyze-<slug> --public --source . --push`.

## 5. Stack e decisões (não trocar sem conversar)

TypeScript estrito · pnpm 10 · Node 22+ · **Astro 7** estático servido como **static assets de
Workers** (não Pages) · **Tailwind 4** (tokens em `hyze-ui/src/styles/global.css`) · **Motion +
Lenis + View Transitions** · **Hono + Zod + D1 + Drizzle + Turnstile** na API · Vitest no runtime
dos Workers · ESLint + Prettier · GitHub Actions (workflows em `.github`) · Renovate.
Tudo no **plano gratuito da Cloudflare**; Next.js descartado (limites de 3 MB/10 ms).
`compatibility_date` em `2026-08-15` (limite do workerd local).

## 6. Identidade e animação

- Cores: `navy-950 #0D1B2A`, `platinum #E0E1DD`; apoio `navy-900 #1B263B`, `navy-700 #415A77`,
  `navy-400 #778DA9`, `platinum-50 #F4F5F2`. Poppins 600 (logo/títulos) e 200 (textos).
- Logo `Hyze.` + rótulo da empresa (`<Logo label="consultoria" />`). Slogan: "Muito além do código".
- Estilo pedido pelo Gabriel: **moderno, clean, fluido, com animações**.
- Ganchos de animação: `data-hero` (entrada), `data-reveal` (ao rolar), `data-stagger`
  (filhos em cascata), `<Logo animated />`; utilitários `card-hover` e `link-underline`.
  Sempre respeitar `prefers-reduced-motion` e funcionar sem JavaScript.
- Use só tokens (`bg-navy-950`…), nunca hex solto nos componentes. Texto público em pt-BR.

## 7. Pendências conhecidas

WhatsApp (`hyze-ui/src/brands.ts`), preços (`src/content.ts` dos sites), cidade do atendimento
presencial (`hyze-consultoria/src/content.ts`), razão social/CNPJ na política de privacidade,
`database_id` do D1 e chaves Turnstile. O Gabriel tem MEI; atividade de desenvolvimento de
software não é permitida ao MEI — assunto para o contador, não altere textos jurídicos sem pedido.
