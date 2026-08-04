import SwiftUI

// MARK: - Multilingual string helper

struct ML {
    let is_IS: String
    let en: String
    let es: String

    func t(_ lang: AppLanguage) -> String {
        switch lang {
        case .icelandic: return is_IS
        case .english:   return en
        case .spanish:   return es
        }
    }
}

// MARK: - Data models

struct TaxTip: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: ML
    let body: ML
}

struct TaxQAItem: Identifiable {
    let id = UUID()
    let question: ML
    let answer: ML
    let tags: [String]
    let icon: String
}

// MARK: - Tip database

private let tipDatabase: [TaxTip] = [
    TaxTip(
        icon: "doc.text.fill",
        color: Color(red: 0.18, green: 0.78, blue: 0.6),
        title: ML(is_IS: "Skattframtal", en: "Tax Return", es: "Declaración de Impuestos"),
        body: ML(
            is_IS: "Skilafrestur er 31. mars. Farðu á skatturinn.is og veldu Mínar síður - sjálfvirkt framtal er þegar tilbúið. Skráðu breytingar áður en þú staðfestir.",
            en: "Filing deadline is March 31. Go to skatturinn.is and select My Pages - your pre-filled return is already ready. Make changes before confirming.",
            es: "El plazo de presentación es el 31 de marzo. Ve a skatturinn.is y selecciona Mis Páginas - tu declaración prellenada ya está lista. Realiza cambios antes de confirmar."
        )
    ),
    TaxTip(
        icon: "shield.fill",
        color: Color(red: 0.2, green: 0.5, blue: 0.9),
        title: ML(is_IS: "Haltu í frá", en: "Set Aside Tax", es: "Reserva para Impuestos"),
        body: ML(
            is_IS: "Verktakar ættu að leggja til hliðar ~35% af hverri greiðslu fyrir skatta og tryggingagjald til að koma í veg fyrir skattskuldur við álagningu.",
            en: "Contractors should set aside ~35% of each payment for income tax and social contributions to avoid a tax bill at year-end assessment.",
            es: "Los contratistas deben reservar ~35% de cada pago para impuestos y contribuciones sociales para evitar deudas tributarias en la liquidación anual."
        )
    ),
    TaxTip(
        icon: "tag.fill",
        color: Color(red: 0.9, green: 0.5, blue: 0.1),
        title: ML(is_IS: "VSK-skráning", en: "VAT Registration", es: "Registro de IVA"),
        body: ML(
            is_IS: "Þegar árleg velta nálgast 2.000.000 kr skaltu skrá þig sem VSK-skyldur áður en þröskuldurinn er náður til að forðast sekt.",
            en: "When annual turnover approaches 2,000,000 ISK, register as VAT-liable before the threshold is reached to avoid penalties.",
            es: "Cuando la facturación anual se acerque a 2.000.000 ISK, regístrate como sujeto al IVA antes de superar el umbral para evitar sanciones."
        )
    ),
    TaxTip(
        icon: "car.fill",
        color: Color(red: 0.4, green: 0.7, blue: 0.3),
        title: ML(is_IS: "Akstursbók", en: "Driving Log", es: "Diario de Conducción"),
        body: ML(
            is_IS: "Haldðu stöðuga akstursbók (dagsetning, upphafstaður, áfangastaður, km, erindi). Skatturinn getur óskað eftir gögnum í allt að 6 ár aftur í tímann.",
            en: "Maintain a consistent driving log (date, from, to, km, purpose). Tax authorities can request records going back up to 6 years.",
            es: "Mantén un registro de conducción constante (fecha, desde, hasta, km, propósito). La autoridad fiscal puede solicitar registros de hasta 6 años atrás."
        )
    ),
    TaxTip(
        icon: "building.columns.fill",
        color: Color(red: 0.6, green: 0.3, blue: 0.8),
        title: ML(
            is_IS: "Viðbótarlífeyrissparnaður",
            en: "Additional Pension Savings",
            es: "Ahorro de Pensión Adicional"
        ),
        body: ML(
            is_IS: "Allt að 4% af launum (launþegar) eða 8% (verktakar) er frádráttarbær. Þetta er ein auðveldasta leiðin til að lækka skattskyld tekjur um þúsundir króna á ári.",
            en: "Up to 4% of salary (employees) or 8% (contractors) is tax-deductible. This is one of the easiest ways to reduce taxable income by thousands of ISK per year.",
            es: "Hasta el 4% del salario (empleados) u 8% (contratistas) es deducible. Es una de las formas más fáciles de reducir la renta gravable en miles de ISK al año."
        )
    ),
    TaxTip(
        icon: "folder.fill",
        color: Color(red: 0.8, green: 0.2, blue: 0.3),
        title: ML(is_IS: "Geymsla gagna", en: "Document Storage", es: "Conservación de Documentos"),
        body: ML(
            is_IS: "Geymdu allar kvittanir og reikninga í a.m.k. 7 ár. Rafrænar skráningar eru jafn gildar og pappírsgögn ef þær eru læsilegar.",
            en: "Keep all receipts and invoices for at least 7 years. Digital records are equally valid as paper documents if they are legible.",
            es: "Guarda todos los recibos y facturas durante al menos 7 años. Los registros digitales son igualmente válidos que los documentos en papel si son legibles."
        )
    ),
]

// MARK: - Q&A database

private let qaDatabase: [TaxQAItem] = [
    TaxQAItem(
        question: ML(
            is_IS: "Hvað er ökutækjastyrkur?",
            en: "What is a vehicle allowance?",
            es: "¿Qué es el subsidio de vehículo?"
        ),
        answer: ML(
            is_IS: """
Ökutækjastyrkur er greiðsla sem launþegi fær frá vinnuveitanda fyrir að nota eigin bifreið í þágu vinnunnar.

Gjaldfrjáls hluti (2025): 66 kr/km fyrir fyrstu 5.000 km á ári, 40 kr/km þar yfir.

Ef styrkurinn er hærri en þessir viðmiðunarfjárhæðir telst munurinn til skattskyldra launatekna og greiðist staðgreiðsla af honum.

Sýnidæmi: 3.000 km x 66 kr = 198.000 kr gjaldfrjálst.
""",
            en: """
A vehicle allowance is a payment an employee receives for using their own car for work.

Tax-free rate (2025): 66 ISK/km for the first 5,000 km per year, 40 ISK/km beyond that.

If the allowance exceeds these amounts, the excess is treated as taxable employment income subject to withholding tax.

Example: 3,000 km x 66 ISK = 198,000 ISK tax-free.
""",
            es: """
El subsidio de vehículo es el pago que recibe un empleado por usar su auto personal para el trabajo.

Tarifa exenta (2025): 66 ISK/km para los primeros 5.000 km al año, 40 ISK/km a partir de entonces.

Si el subsidio supera estos importes, el exceso se trata como ingreso laboral sujeto a retención.

Ejemplo: 3.000 km x 66 ISK = 198.000 ISK exentos.
"""
        ),
        tags: ["ökutæki", "bifreið", "akstur", "styrkur", "km", "kílómetrar", "vehicle", "allowance", "vehículo", "subsidio"],
        icon: "car.fill"
    ),
    TaxQAItem(
        question: ML(
            is_IS: "Hvað eru dagpeningar?",
            en: "What are per diem allowances?",
            es: "¿Qué son los viáticos?"
        ),
        answer: ML(
            is_IS: """
Dagpeningar eru greiðslur á móti kostnaði vegna ferðalaga í þágu vinnu, t.d. gistingu og mataræði.

Gjaldfrjálsir dagpeningar innanlands (2025): 23.000-25.000 kr/dag eftir ferðalengd.

Dagpeningar eru skattskyldur hluti þeirra greiðslna sem fara yfir gjaldfrjálsa mörkin.

Til að fá dagpeninga þarf ferðin að vera vegna vinnu og launþegi að dvelja fjarri lögheimili.
""",
            en: """
Per diems are payments for costs incurred during work-related travel, such as accommodation and meals.

Tax-free domestic per diems (2025): 23,000-25,000 ISK/day depending on trip duration.

Amounts above the tax-free limit are treated as taxable income.

Eligibility requires the trip to be work-related and away from the registered home address.
""",
            es: """
Los viáticos son pagos por gastos incurridos en viajes de trabajo, como alojamiento y comidas.

Viáticos domésticos exentos (2025): 23.000-25.000 ISK/día según la duración del viaje.

Los montos que superen el límite exento se tratan como ingresos sujetos a impuesto.

Para tener derecho, el viaje debe ser laboral y alejado del domicilio registrado.
"""
        ),
        tags: ["dagpeningar", "ferðakostnaður", "gisting", "matur", "ferð", "per diem", "travel", "viáticos", "dietas"],
        icon: "airplane"
    ),
    TaxQAItem(
        question: ML(
            is_IS: "Hvenær er skattframtal?",
            en: "When is the tax return deadline?",
            es: "¿Cuándo vence la declaración de impuestos?"
        ),
        answer: ML(
            is_IS: """
Skattframtal einstaklinga er almennt lagt fram í mars-apríl ár hvert.

Frestur til að skila rafrænu skattframtali er venjulega 31. mars.

Á vef Skatturinn (skatturinn.is) undir Mínar síður er hægt að skoða og breyta skattframtali.

Rafrænt undirritað framtal er sent beint frá vefsíðu - engin pappírsblöð þarf.

Ef þú breytir engu er sjálfvirkt framtal lagt fram í þínu nafni.
""",
            en: """
Individual tax returns are generally filed between March and April each year.

The e-filing deadline is typically March 31.

At skatturinn.is under My Pages you can view and amend your pre-filled return.

Electronic submissions are sent directly from the website - no paper forms required.

If you make no changes, the auto-generated return is filed on your behalf.
""",
            es: """
Las declaraciones individuales generalmente se presentan entre marzo y abril de cada año.

El plazo de presentación electrónica es normalmente el 31 de marzo.

En skatturinn.is bajo Mis Páginas puedes ver y modificar tu declaración prellenada.

Las presentaciones se envían directamente desde la web, sin formularios en papel.

Si no realizas cambios, la declaración automática se presenta en tu nombre.
"""
        ),
        tags: ["skattframtal", "framtal", "mars", "apríl", "skatturinn", "tax return", "deadline", "declaración", "plazo"],
        icon: "calendar"
    ),
    TaxQAItem(
        question: ML(
            is_IS: "Hvað er staðgreiðsla?",
            en: "What is withholding tax (PAYE)?",
            es: "¿Qué es la retención en origen?"
        ),
        answer: ML(
            is_IS: """
Staðgreiðsla er fyrirframgreiðsla tekjuskatts og tryggingagjalds sem dregin er af launum áður en þau eru greidd út.

Staðgreiðsluhlutfall er reiknað út frá launum og persónuafslætti hvers og eins.

Launagreiðendur skila staðgreiðslunni til ríkissjóðs mánaðarlega.

Ef of mikil staðgreiðsla hefur verið dregin fær launþegi endurgreiðslu við álagningu - og öfugt.
""",
            en: """
Withholding tax is an advance payment of income tax and social contributions deducted from your salary before payment.

The withholding rate is calculated based on your income and personal tax credit.

Employers remit the withholding to the Treasury monthly.

If too much is withheld you receive a refund at assessment; if too little, you owe the difference.
""",
            es: """
La retención en origen es un pago anticipado de impuesto a la renta y contribuciones sociales descontado de tu salario.

La tasa de retención se calcula en base a tus ingresos y tu crédito fiscal personal.

Los empleadores remiten la retención al Tesoro mensualmente.

Si se retiene de más recibes un reembolso en la liquidación; si de menos, debes pagar la diferencia.
"""
        ),
        tags: ["staðgreiðsla", "skattar", "laun", "endurgreiðsla", "álagning", "withholding", "PAYE", "retención", "nómina"],
        icon: "percent"
    ),
    TaxQAItem(
        question: ML(
            is_IS: "Hvað er persónuafsláttur?",
            en: "What is the personal tax credit?",
            es: "¿Qué es el crédito fiscal personal?"
        ),
        answer: ML(
            is_IS: """
Persónuafsláttur er skattalegt frádráttarheimild sem dregur beint úr útreiknaðri skattfjárhæð.

Fjárhæð 2025: 60.995 kr/mánuð (731.940 kr/ár).

Ef persónuafsláttur er ekki nýttur að fullu hjá einum launagreiðanda er hægt að framselja hluta maka.

Einstaklingar sem fá lífeyri fá lífeyrisþegaafslætti til viðbótar.
""",
            en: """
The personal tax credit is a tax deduction that reduces your calculated tax liability directly.

2025 amount: 60,995 ISK/month (731,940 ISK/year).

If the full credit is not used by one employer, you can transfer part to a spouse.

Pensioners receive an additional pension recipient credit.
""",
            es: """
El crédito fiscal personal es una deducción que reduce directamente tu obligación tributaria calculada.

Monto 2025: 60.995 ISK/mes (731.940 ISK/año).

Si el crédito completo no lo usa un solo empleador, puedes transferir parte a tu cónyuge.

Los pensionistas reciben un crédito adicional para receptores de pensión.
"""
        ),
        tags: ["persónuafsláttur", "skattur", "frádráttur", "maki", "framsala", "personal credit", "tax credit", "crédito", "deducción"],
        icon: "minus.circle.fill"
    ),
    TaxQAItem(
        question: ML(
            is_IS: "Hvað er VSK og þarf ég að skrá mig?",
            en: "What is VAT and do I need to register?",
            es: "¿Qué es el IVA y necesito registrarme?"
        ),
        answer: ML(
            is_IS: """
VSK (virðisaukaskattur) er skattur á sölu vara og þjónustu. Almenna VSK-hlutfallið er 24%.

Skráningarskylda: Ef árleg velta fer yfir 2.000.000 kr verður þú að skrá þig sem VSK-skyldur aðili.

Skráning fer fram hjá Skatturinn og tekur gildi frá þeim mánuði sem þröskuldurinn er náð.

VSK-skyldir aðilar skila VSK-skýrslu mánaðarlega eða á tveggja mánaða fresti.
""",
            en: """
VAT (virðisaukaskattur) is a tax on the sale of goods and services. The standard rate is 24%.

Registration requirement: If annual turnover exceeds 2,000,000 ISK, you must register as VAT-liable.

Registration is done at Skatturinn and takes effect from the month the threshold is reached.

VAT-registered entities file VAT returns monthly or bimonthly.
""",
            es: """
El IVA (virðisaukaskattur) es un impuesto sobre la venta de bienes y servicios. La tasa general es del 24%.

Obligacion de registro: Si la facturación anual supera 2.000.000 ISK, debes registrarte como sujeto al IVA.

El registro se realiza en Skatturinn y entra en vigor desde el mes en que se alcanza el umbral.

Las entidades registradas presentan declaraciones de IVA mensuales o bimestrales.
"""
        ),
        tags: ["vsk", "virðisaukaskattur", "þröskuldur", "skráning", "verktaki", "VAT", "value added tax", "IVA", "registro"],
        icon: "tag.fill"
    ),
    TaxQAItem(
        question: ML(
            is_IS: "Get ég dregið frá heimilisskrifstofu?",
            en: "Can I deduct a home office?",
            es: "¿Puedo deducir una oficina en casa?"
        ),
        answer: ML(
            is_IS: """
Frádráttur vegna heimilisskrifstofu er mögulegur ef þú starfar sem verktaki og notar hluta heimilisins eingöngu í atvinnuskyni.

Þú getur dregið frá hlutfallslegan húsaleigu- eða húsfjárhagskostnað, hita, rafmagn og nettengingu sem stendur til sögunnar við atvinnustarfsemina.

Settu upp skráningu á raunverulegum kostnaði og geymdu kvittanir sem fylgigögn við skattframtal.
""",
            en: """
A home office deduction is possible if you work as a contractor and use part of your home exclusively for business.

You can deduct a proportional share of rent or mortgage, heating, electricity, and internet related to your business use.

Keep records of actual costs and retain receipts as supporting documentation for your tax return.
""",
            es: """
La deduccion por oficina en casa es posible si trabajas como contratista y usas parte de tu hogar exclusivamente para negocios.

Puedes deducir una parte proporcional del alquiler o hipoteca, calefaccion, electricidad e internet relacionados con el uso empresarial.

Lleva registro de los costos reales y guarda los recibos como documentacion de respaldo para tu declaracion.
"""
        ),
        tags: ["heimili", "skrifstofa", "heimaskrifstofa", "frádráttur", "leiga", "rafmagn", "home office", "deduction", "oficina", "deduccion"],
        icon: "house.fill"
    ),
    TaxQAItem(
        question: ML(
            is_IS: "Hvernig skrái ég hlutabréf og arð?",
            en: "How do I report stocks and dividends?",
            es: "¿Cómo declaro acciones y dividendos?"
        ),
        answer: ML(
            is_IS: """
Arður frá hlutabréfum er skattskyldur og skráður á skattframtali.

Íslenskir útgefendur halda eftir 20% staðgreiðslu af arði (staðgreiðsla af fjármagnstekjum).

Erlend hlutabréf: Arður sem þú færð án staðgreiðslu þarf að skrá sjálfur og greiða 20% fjármagnstekjuskatt.

Söluhagnaður af hlutabréfum (kaupverð frá söluverði) telst einnig til fjármagnstekna og skattlagður á sama máta.
""",
            en: """
Dividends from shares are taxable and reported on your tax return.

Icelandic issuers withhold 20% tax on dividends (capital income withholding tax).

Foreign shares: Dividends received without withholding must be self-declared and 20% capital income tax paid.

Capital gains from share sales (sale price minus purchase price) also count as capital income and are taxed the same way.
""",
            es: """
Los dividendos de acciones son gravables y se declaran en la declaracion de impuestos.

Los emisores islandeses retienen el 20% de impuesto sobre dividendos (retencion sobre ingresos de capital).

Acciones extranjeras: los dividendos recibidos sin retencion deben autodeclararse y pagarse el 20% de impuesto a la renta de capital.

Las ganancias de capital por venta de acciones (precio de venta menos precio de compra) tambien tributan como ingresos de capital.
"""
        ),
        tags: ["hlutabréf", "arður", "fjármagnstekjur", "skattur", "sala", "stocks", "dividends", "shares", "acciones", "dividendos"],
        icon: "chart.line.uptrend.xyaxis"
    ),
    TaxQAItem(
        question: ML(
            is_IS: "Hvernig virkar lífeyrissparnaður skattlega?",
            en: "How does pension savings work for taxes?",
            es: "¿Cómo funciona el ahorro de pension en cuanto a impuestos?"
        ),
        answer: ML(
            is_IS: """
Iðgjald í lífeyrissjóð (4% lágmarksiðgjald launþega) dregst frá skattskyldum tekjum.

Viðbótarlífeyrissparnaður: Þú getur lagt til viðbótar allt að 4% af launum (launþegi) eða 8% (verktaki) og fengið frádráttarheimild fyrir þá fjárhæð.

Lífeyrissparnaður er skattlaus meðan hann vex - skattur er greiddur við útgreiðslu.

Tryggingagjald skiptist 2/3 hluta launagreiðanda og 1/3 hluta launþega.
""",
            en: """
Pension fund contributions (4% mandatory employee contribution) are deducted from taxable income.

Additional pension savings: You can contribute up to an extra 4% of salary (employees) or 8% (contractors) and receive a tax deduction for that amount.

Pension savings grow tax-free - tax is paid upon withdrawal.

Social contributions split: 2/3 employer, 1/3 employee.
""",
            es: """
Las aportaciones al fondo de pensiones (4% de aportacion obligatoria del empleado) se deducen de los ingresos gravables.

Ahorro adicional: puedes aportar hasta un 4% extra del salario (empleados) u 8% (contratistas) y recibir una deduccion fiscal.

El ahorro de pension crece libre de impuestos: el impuesto se paga al momento del retiro.

Distribucion de las contribuciones sociales: 2/3 empleador, 1/3 empleado.
"""
        ),
        tags: ["lífeyrir", "lífeyrissparnaður", "iðgjald", "frádráttur", "sparnaður", "pension", "savings", "retirement", "pension", "ahorro"],
        icon: "building.columns.fill"
    ),
    TaxQAItem(
        question: ML(
            is_IS: "Hvað er munurinn á verktaka og launþega?",
            en: "What is the difference between contractor and employee?",
            es: "¿Cual es la diferencia entre contratista y empleado?"
        ),
        answer: ML(
            is_IS: """
Launþegi: Starfar á grundvelli ráðningarsamnings. Vinnuveitandinn greiðir tryggingagjald og dregur staðgreiðslu af launum.

Verktaki: Starfar á eigin kennitölu eða í gegnum eigið fyrirtæki, gefur út reikninga og ber ábyrgð á skattgreiðslum sjálfur.

Blönduð staða: Mörgur Íslendingar eru bæði launþegar og verktakar - tekjurnar hafa sitt hvora skattlegu meðferð.

Munurinn skiptir máli fyrir VSK-skráningarskyldu, frádráttarheimildir og skil staðgreiðslu.
""",
            en: """
Employee: Works under an employment contract; the employer pays social contributions and deducts withholding tax from wages.

Contractor: Works on their own ID number or through their own company; issues invoices and is responsible for their own tax payments.

Hybrid: Many Icelanders are both employees and contractors - each income type has its own tax treatment.

The distinction matters for VAT registration, deductible expenses, and withholding tax obligations.
""",
            es: """
Empleado: Trabaja bajo contrato laboral; el empleador paga las contribuciones sociales y retiene el impuesto del salario.

Contratista: Trabaja con su propio numero de identificacion o a traves de su propia empresa; emite facturas y es responsable de sus propios pagos de impuestos.

Mixto: Muchos islandeses son tanto empleados como contratistas - cada tipo de ingreso tiene su propio tratamiento fiscal.

La distincion importa para el registro de IVA, gastos deducibles y obligaciones de retencion.
"""
        ),
        tags: ["verktaki", "launþegi", "ráðning", "samningur", "munur", "contractor", "employee", "freelance", "contratista", "empleado"],
        icon: "person.2.fill"
    ),
]

// MARK: - Pending question store

private let pendingQuestionsKey = "taxis.pendingQuestions"

private func storePendingQuestion(_ q: String) {
    var existing = (UserDefaults.standard.array(forKey: pendingQuestionsKey) as? [String]) ?? []
    let trimmed = q.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, !existing.contains(trimmed) else { return }
    existing.append(trimmed)
    UserDefaults.standard.set(existing, forKey: pendingQuestionsKey)
}

// MARK: - View

struct FærslurView: View {
    @EnvironmentObject private var lm: LocalizationManager
    @State private var searchText = ""
    @State private var expandedID: UUID?
    @State private var showNoMatch = false
    @State private var activeSection: Section = .tips

    enum Section: CaseIterable { case tips, qa }

    private func sectionLabel(_ s: Section) -> String {
        switch s {
        case .tips: return lm.t(.abendingar)
        case .qa:   return lm.t(.spurningar)
        }
    }

    private func filteredQA() -> [TaxQAItem] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return qaDatabase }
        let words = q.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return qaDatabase.filter { item in
            let haystack = (
                item.question.t(lm.language) + " " +
                item.answer.t(lm.language) + " " +
                item.tags.joined(separator: " ")
            ).lowercased()
            return words.contains { haystack.contains($0) }
        }
    }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pageHeader
                    sectionPicker
                    if activeSection == .tips {
                        tipsSection
                    } else {
                        qaSection
                    }
                }
                .padding(18)
                .padding(.top, 8)   // safeAreaPadding(.top) below handles status bar
                .padding(.bottom, 30)
            }
            // Respect the actual top safe area (Dynamic Island, notch, status bar)
            // so the title never slides under the system UI on any device.
            .safeAreaPadding(.top)
        }
    }

    // MARK: Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lm.t(.tabInsights))
                .font(.title2.bold())
                .foregroundStyle(TaxIsTheme.navy)
            Text(lm.t(.faerslaSubtitle))
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.muted)
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(Section.allCases, id: \.self) { s in
                Button { activeSection = s } label: {
                    Text(sectionLabel(s))
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(activeSection == s ? TaxIsTheme.mint : Color.clear)
                        .foregroundStyle(activeSection == s ? TaxIsTheme.onMint : TaxIsTheme.muted)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control - 1))
                }
                .buttonStyle(.plain)
                .padding(2)
            }
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    // MARK: Tips

    private var tipsSection: some View {
        VStack(spacing: 12) {
            ForEach(tipDatabase) { tip in
                tipCard(tip)
            }
        }
    }

    private func tipCard(_ tip: TaxTip) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tip.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tip.color)
                .frame(width: 36, height: 36)
                .background(tip.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title.t(lm.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.text)
                Text(tip.body.t(lm.language))
                    .font(.footnote)
                    .foregroundStyle(TaxIsTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    // MARK: Q&A

    private var qaSection: some View {
        VStack(spacing: 12) {
            searchBar
            let results = filteredQA()
            if showNoMatch || (results.isEmpty && !searchText.isEmpty) {
                noMatchCard
            } else {
                ForEach(results) { item in
                    qaRow(item)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.muted)
            TextField(lm.t(.searchPlaceholder), text: $searchText)
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.text)
                .onSubmit { handleSearchSubmit() }
            if !searchText.isEmpty {
                Button { searchText = ""; showNoMatch = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(TaxIsTheme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func handleSearchSubmit() {
        if filteredQA().isEmpty && !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            storePendingQuestion(searchText)
            showNoMatch = true
        }
    }

    private var noMatchCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(TaxIsTheme.mint)
                Text(lm.t(.questionReceived))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.text)
            }
            Text(lm.t(.questionReceivedBody))
                .font(.footnote)
                .foregroundStyle(TaxIsTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaxIsTheme.mintTint)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.mint.opacity(0.4), lineWidth: 1))
    }

    private func qaRow(_ item: TaxQAItem) -> some View {
        let isExpanded = expandedID == item.id
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedID = isExpanded ? nil : item.id
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TaxIsTheme.mint)
                        .frame(width: 30, height: 30)
                        .background(TaxIsTheme.mintTint)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(item.question.t(lm.language))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TaxIsTheme.text)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TaxIsTheme.muted)
                }
                .padding(13)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(TaxIsTheme.border)
                Text(item.answer.t(lm.language))
                    .font(.footnote)
                    .foregroundStyle(TaxIsTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(isExpanded ? TaxIsTheme.mint.opacity(0.4) : TaxIsTheme.border, lineWidth: 1))
    }
}

#Preview {
    FærslurView()
        .environmentObject(LocalizationManager.shared)
}
