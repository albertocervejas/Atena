import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "https://albertocervejas.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const groups = {
  "Despesas Fixas": ["Salários e encargos", "Pró-labore", "Aluguel e condomínio", "Energia elétrica", "Água e gás", "Internet e telefonia", "Contabilidade e serviços profissionais", "Sistemas e softwares", "Seguros", "Manutenção e limpeza", "Depreciação e amortização", "Despesas bancárias fixas", "Outra conta"],
  "Despesas Variáveis": ["Matéria Prima", "Insumos", "Aviamentos e materiais de produção", "Facção e serviços de costura", "Embalagens e etiquetas", "Comissões de vendas", "Fretes e entregas", "Taxas de cartão e marketplace", "Impostos sobre vendas", "Mão de obra temporária", "Outros custos variáveis", "Outra conta"],
  "Despesas Diversas": ["Material de escritório", "Deslocamentos e viagens", "Alimentação e representação", "Juros e multas", "Tarifas bancárias", "Marketing e publicidade", "Treinamentos", "Doações e brindes", "Outras despesas diversas", "Outra conta"],
  "Investimentos": ["Máquinas e equipamentos", "Móveis e utensílios", "Computadores e tecnologia", "Benfeitorias e instalações", "Reforma de loja", "Desenvolvimento de coleção", "Expansão e abertura de unidade", "Outros investimentos", "Outra conta"],
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return Response.json({ error: "Método não permitido." }, { status: 405, headers: cors });

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return Response.json({ error: "Acesso não autorizado." }, { status: 401, headers: cors });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  // New Supabase projects expose key collections; retain legacy names for older projects.
  const publishableKeys = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") || "{}");
  const secretKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || publishableKeys.default;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || secretKeys.default;
  if (!anonKey || !serviceKey) return Response.json({ error: "Configuração segura do Supabase incompleta." }, { status: 503, headers: cors });
  const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return Response.json({ error: "Acesso não autorizado." }, { status: 401, headers: cors });
  const { data: allowedName, error: allowError } = await userClient.rpc("atena_current_user_name");
  if (allowError || !allowedName) return Response.json({ error: "Este e-mail não está autorizado para acessar a Atena." }, { status: 403, headers: cors });

  try {
    const { path } = await req.json();
    if (typeof path !== "string" || !path.startsWith(`${user.id}/`) || path.includes("..")) {
      return Response.json({ error: "Caminho de comprovante inválido." }, { status: 400, headers: cors });
    }
    const admin = createClient(supabaseUrl, serviceKey);
    const { data: file, error: fileError } = await admin.storage.from("atena-expense-receipts").download(path);
    if (fileError || !file) return Response.json({ error: "Não foi possível abrir o comprovante privado." }, { status: 404, headers: cors });
    if (file.size > 15 * 1024 * 1024) return Response.json({ error: "O arquivo ultrapassa o limite de 15 MB." }, { status: 413, headers: cors });

    const openAIKey = Deno.env.get("OPENAI_API_KEY");
    if (!openAIKey) return Response.json({ error: "O serviço de leitura ainda não está configurado." }, { status: 503, headers: cors });
    const model = Deno.env.get("OPENAI_MODEL") || "gpt-4o-mini";
    const bytes = new Uint8Array(await file.arrayBuffer());
    let binary = "";
    for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
    const base64 = btoa(binary);
    const mime = file.type === "application/pdf" ? "application/pdf" : file.type === "image/png" ? "image/png" : "image/jpeg";
    const fileItem = mime === "application/pdf"
      ? { type: "input_file", filename: "comprovante.pdf", file_data: `data:${mime};base64,${base64}`, detail: "high" }
      : { type: "input_image", image_url: `data:${mime};base64,${base64}`, detail: "high" };
    const schema = {
      type: "object", additionalProperties: false,
      properties: {
        description: { type: ["string", "null"] }, vendor: { type: ["string", "null"] },
        expense_date: { type: ["string", "null"], description: "Data do documento em YYYY-MM-DD" },
        due_date: { type: ["string", "null"], description: "Vencimento em YYYY-MM-DD" },
        paid_date: { type: ["string", "null"], description: "Pagamento efetivo em YYYY-MM-DD" },
        amount: { type: ["number", "null"], description: "Valor principal sem juros, em reais" },
        interest: { type: ["number", "null"], description: "Juros e encargos em reais, se explicitamente indicados" },
        payment_method: { type: ["string", "null"] },
        category_group: { type: ["string", "null"], enum: ["Despesas Fixas", "Despesas Variáveis", "Despesas Diversas", "Investimentos", null] },
        account_name: { type: ["string", "null"] },
      },
      required: ["description", "vendor", "expense_date", "due_date", "paid_date", "amount", "interest", "payment_method", "category_group", "account_name"],
    };
    const prompt = `Leia o comprovante financeiro da Atena e extraia apenas informações visíveis. Responda em português. Não invente dados: use null quando não estiverem claros. Datas em YYYY-MM-DD; valores numéricos em reais. Diferencie data do documento, vencimento e pagamento efetivo. Extraia juros somente quando estiverem destacados; amount deve ser o principal sem juros. Sugira uma conta e uma das categorias apenas quando houver evidência suficiente. Categorias e plano de contas disponíveis: ${JSON.stringify(groups)}. Nunca trate saldo, limite de cartão ou troco como valor da despesa.`;
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { "Authorization": `Bearer ${openAIKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model, store: false, input: [{ role: "user", content: [{ type: "input_text", text: prompt }, fileItem] }], text: { format: { type: "json_schema", name: "atena_expense_receipt", strict: true, schema } } }),
    });
    if (!response.ok) return Response.json({ error: "A leitura do comprovante falhou. Tente novamente ou preencha os campos manualmente." }, { status: 502, headers: cors });
    const result = await response.json();
    const text = result.output?.flatMap((item: any) => item.content || []).find((part: any) => part.type === "output_text")?.text;
    if (!text) return Response.json({ error: "A IA não conseguiu extrair dados deste comprovante." }, { status: 422, headers: cors });
    const extraction = JSON.parse(text);
    if (extraction.category_group && !groups[extraction.category_group as keyof typeof groups]?.includes(extraction.account_name)) extraction.account_name = null;
    return Response.json({ extraction }, { headers: cors });
  } catch (_error) {
    return Response.json({ error: "Não foi possível processar o comprovante. Você ainda pode preencher manualmente." }, { status: 500, headers: cors });
  }
});
