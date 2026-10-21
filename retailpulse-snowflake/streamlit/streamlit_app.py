# ==========================================================
# RetailPulse - Tableau de bord des ventes (Streamlit in Snowflake)
# Source : RETAIL_DB.ANALYTICS.FACT_SALES
# ==========================================================
import altair as alt
import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

BLEU = "#29B5E8"  # le bleu Snowflake

# ----------------------------------------------------------
# 1. Connexion et lecture des donnees
# ----------------------------------------------------------
session = get_active_session()
df = session.table("RETAIL_DB.ANALYTICS.FACT_SALES").to_pandas()
df["TOTAL_AMOUNT"] = df["TOTAL_AMOUNT"].astype(float)
df["NB_ITEMS"] = df["NB_ITEMS"].astype(int)
df["JOUR"] = pd.to_datetime(df["EVENT_TIMESTAMP"]).dt.normalize()


def euros(montant):
    """80487.4 -> '80 487,40 €'"""
    return f"{montant:,.2f} €".replace(",", " ").replace(".", ",")


def entier(nombre):
    """1758 -> '1 758'"""
    return f"{nombre:,}".replace(",", " ")


# ----------------------------------------------------------
# 2. Style des cartes KPI (CSS)
# ----------------------------------------------------------
st.markdown(
    """
<style>
.kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: 12px;
  margin: 8px 0 28px 0;
}
.kpi {
  background: rgba(41, 181, 232, 0.10);
  border: 1px solid rgba(41, 181, 232, 0.35);
  border-radius: 12px;
  padding: 14px 16px;
}
.kpi-label { font-size: 0.85rem; opacity: 0.75; margin-bottom: 4px; }
.kpi-value { font-size: 1.6rem; font-weight: 700; line-height: 1.2; }
.kpi-sub { font-size: 0.8rem; opacity: 0.7; margin-top: 4px; }
</style>
""",
    unsafe_allow_html=True,
)

# ----------------------------------------------------------
# 3. En-tete
# ----------------------------------------------------------
st.title("📊 RetailPulse")
st.caption(
    f"Tableau de bord des ventes · Source : RETAIL_DB.ANALYTICS.FACT_SALES · "
    f"Dernier chargement : {pd.to_datetime(df['LOADED_AT']).max():%d/%m/%Y %H:%M}"
)

# ----------------------------------------------------------
# 4. Filtre (dans la barre laterale)
# ----------------------------------------------------------
st.sidebar.header("Filtres")
tous_les_pays = sorted(df["COUNTRY"].unique())
pays_choisis = st.sidebar.multiselect("Pays", tous_les_pays, default=tous_les_pays)

if not pays_choisis:
    st.warning("Choisis au moins un pays dans la barre latérale.")
    st.stop()

ventes = df[df["COUNTRY"].isin(pays_choisis)]

# ----------------------------------------------------------
# 5. Cartes KPI
# ----------------------------------------------------------
nb_commandes = len(ventes)
chiffre_affaires = ventes["TOTAL_AMOUNT"].sum()
nb_articles = int(ventes["NB_ITEMS"].sum())
panier_moyen = chiffre_affaires / nb_commandes

# Part du chiffre d'affaires global (tous pays confondus)
ca_global = df["TOTAL_AMOUNT"].sum()
if len(pays_choisis) == len(tous_les_pays):
    sous_titre_ca = "Tous les pays"
else:
    part = chiffre_affaires / ca_global * 100
    sous_titre_ca = (
        f"{part:.1f} % du CA global ({euros(ca_global)})".replace(".", ",", 1)
    )

# (titre, valeur, sous-titre facultatif)
cartes = [
    ("🧾 Commandes", entier(nb_commandes), ""),
    ("💶 Chiffre d'affaires", euros(chiffre_affaires), sous_titre_ca),
    ("👕 Articles vendus", entier(nb_articles), ""),
    ("🛒 Panier moyen", euros(panier_moyen), ""),
]
html = '<div class="kpi-grid">' + "".join(
    f'<div class="kpi"><div class="kpi-label">{titre}</div>'
    f'<div class="kpi-value">{valeur}</div>'
    + (f'<div class="kpi-sub">{sous_titre}</div>' if sous_titre else "")
    + "</div>"
    for titre, valeur, sous_titre in cartes
) + "</div>"
st.markdown(html, unsafe_allow_html=True)

# ----------------------------------------------------------
# 6. Graphique : chiffre d'affaires par pays (barres horizontales)
# ----------------------------------------------------------
st.subheader("Chiffre d'affaires par pays")
ca_pays = ventes.groupby("COUNTRY", as_index=False)["TOTAL_AMOUNT"].sum()

barres = alt.Chart(ca_pays).mark_bar(color=BLEU).encode(
    x=alt.X("TOTAL_AMOUNT:Q", title="Chiffre d'affaires (€)"),
    y=alt.Y("COUNTRY:N", sort="-x", title=None),
    tooltip=[
        alt.Tooltip("COUNTRY:N", title="Pays"),
        alt.Tooltip("TOTAL_AMOUNT:Q", title="CA (€)", format=",.2f"),
    ],
)
etiquettes = barres.mark_text(align="left", dx=4, color="#9AA0A6").encode(
    text=alt.Text("TOTAL_AMOUNT:Q", format=",.0f")
)
st.altair_chart(barres + etiquettes, use_container_width=True)

# ----------------------------------------------------------
# 7. Graphique : chiffre d'affaires par jour (courbe)
# ----------------------------------------------------------
st.subheader("Chiffre d'affaires par jour")
ca_jour = ventes.groupby("JOUR", as_index=False)["TOTAL_AMOUNT"].sum()

courbe = alt.Chart(ca_jour).mark_line(point=True, color=BLEU).encode(
    x=alt.X("JOUR:T", title=None, axis=alt.Axis(format="%d/%m")),
    y=alt.Y("TOTAL_AMOUNT:Q", title="Chiffre d'affaires (€)"),
    tooltip=[
        alt.Tooltip("JOUR:T", title="Jour", format="%d/%m/%Y"),
        alt.Tooltip("TOTAL_AMOUNT:Q", title="CA (€)", format=",.2f"),
    ],
)
st.altair_chart(courbe, use_container_width=True)

# ----------------------------------------------------------
# 8. Tableau des dernieres ventes
# ----------------------------------------------------------
st.subheader("Dernières ventes")
dernieres = (
    ventes.sort_values("EVENT_TIMESTAMP", ascending=False)
    .head(20)[["TRANSACTION_ID", "CUSTOMER_ID", "COUNTRY", "NB_ITEMS", "TOTAL_AMOUNT", "EVENT_TIMESTAMP"]]
    .rename(columns={
        "TRANSACTION_ID": "Commande",
        "CUSTOMER_ID": "Client",
        "COUNTRY": "Pays",
        "NB_ITEMS": "Articles",
        "TOTAL_AMOUNT": "Montant",
        "EVENT_TIMESTAMP": "Date",
    })
)
st.dataframe(
    dernieres.style.format({
        "Montant": lambda v: euros(v),
        "Date": lambda d: f"{pd.to_datetime(d):%d/%m/%Y %H:%M}",
    }),
    use_container_width=True,
    hide_index=True,
)
