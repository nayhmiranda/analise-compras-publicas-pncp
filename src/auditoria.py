import pandas as pd

compras = pd.read_csv("data/raw/compras.csv", dtype=str)
itens = pd.read_csv("data/raw/itens.csv", dtype=str)
resultados = pd.read_csv("data/raw/resultados.csv", dtype=str)

for nome, df in [("compras", compras), ("itens", itens), ("resultados", resultados)]:
    print(nome, df.shape)
    print(df.head(3).T)