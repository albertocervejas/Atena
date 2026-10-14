# Atena — configuração do Supabase

## Projeto configurado

- Projeto: **Atena BI** (`orgdmnwhwvojeekpfdhw`).
- Bucket `atena-private`: privado, com leitura permitida somente a usuários autorizados.
- Migração aplicada: tabela de categorias compartilhadas com RLS, funções de autorização e bucket privado.
- Pessoas autorizadas: quatro e-mails cadastrados em `private.atena_authorized_users`; a lista permanece em `authorized_users.sql`, ignorada pelo Git.
- Importação inicial: dados comerciais e telefones enviados como `dashboard.json.gz`; 639 códigos de produto carregados em `atena_product_categories`.
- URL de autenticação: `https://albertocervejas.github.io/Atena/` cadastrada como endereço padrão; os dois endereços GitHub Pages seguem permitidos para redirecionamento.

## Financeiro

- As tabelas compartilhadas, políticas RLS e o bucket privado de comprovantes foram aplicados no projeto Atena BI. O arquivo `migrations/202610140001_atena_finance.sql` registra a estrutura para futuras instalações.
- A Edge Function `atena-expense-extract` ainda precisa ser implantada e receber `OPENAI_API_KEY` nos secrets de Edge Functions do projeto. `OPENAI_MODEL` é opcional (padrão `gpt-4o-mini`). Nunca publique essa chave no GitHub nem no código do site.
- O botão “Ler comprovante com IA” só envia o arquivo ao provedor quando clicado. A resposta é uma sugestão, revisada pela pessoa antes de salvar.
- A base comercial atual tem data de emissão, valores e lucro, mas não vencimentos de recebimentos. Para o fluxo usar a data de vencimento solicitada, registre as parcelas na área “Programar recebimentos de vendas”. As despesas também entram pelo vencimento.
- A DRE usa a data de emissão. O CMV é calculado por linha como faturamento menos o campo “lucro” do relatório. As contas `Matéria Prima` e `Insumos` cadastradas em despesas são excluídas da DRE para não duplicar o CMV.
- O plano de contas é um modelo gerencial inicial para a Atena, com base em exemplos do Sebrae para confecção e nos conceitos de custos de produção do CPC 16; deve ser revisado pela contabilidade da empresa antes de uso fiscal.

Para implantar a função quando houver uma chave da OpenAI cadastrada, na pasta do projeto:

```text
supabase link --project-ref orgdmnwhwvojeekpfdhw
supabase functions deploy atena-expense-extract
```

Cadastre `OPENAI_API_KEY` em Supabase Dashboard → Edge Functions → Secrets (ou use um `.env` local ignorado pelo Git com `supabase secrets set --env-file ...`). A chave não precisa ser enviada no chat. O Supabase fornece as próprias chaves do projeto à Edge Function; elas não devem ser copiadas para o arquivo público do painel.

## Configuração do site

O arquivo `../supabase-config.js` contém somente a URL do projeto e a chave publicável. Essa chave pode ser publicada porque as tabelas e o bucket são protegidos por RLS e políticas de acesso. Nunca coloque uma chave `sb_secret_` ou `service_role` nesse arquivo, no GitHub ou em mensagens.

O workflow do GitHub Pages publica somente a interface (`index.html`, `logo-atena.png` e `supabase-config.js`). Vendas, clientes e telefones ficam no bucket privado.

## Atualizar os dados futuramente

No computador que contém `data.js` e `client-phones.js`, defina `ATENA_SUPABASE_URL` e `ATENA_SUPABASE_SERVICE_KEY` no ambiente e execute `scripts/import_atena_private_data.py`. O script confere o identificador do projeto Atena BI antes do envio, compacta o arquivo e atualiza os dados e as categorias iniciais. A chave secreta é usada somente localmente e deve ser removida do ambiente após o envio.

Se o endereço publicado do painel mudar, atualize o Site URL e a lista Redirect URLs em Authentication → URL Configuration. Use o endereço exato do site publicado.

