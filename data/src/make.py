# Make example datasets from raw data files

# See data/README.md for the sources of data files
# Paths for the data files need to be specified in data/src/config.py
# config.py contains a Dictionary named rawpaths
# with keys being the name of each output file (and the method for processing)
# and values being the path for each raw data file

import pandas as pd
from config import rawpaths

def hrs(outdir):
    df = pd.read_stata(rawpaths['hrs'])
    cols1 = ['hhidpn', 'wave', 'wave_hosp', 'evt_time', 'oop_spend', 'riearnsemp', 'rwthh']
    cols2 = ['male', 'spouse', 'white', 'black', 'hispanic']
    df = df[(df.wave>=7)&(df.age_hosp<=59)][cols1+cols2]
    df['nwave'] = df.groupby('hhidpn')['wave'].transform('size')
    df = df[df.nwave==5]
    df['min_evt_time'] = df.groupby('hhidpn')['evt_time'].transform('min')
    df = df[~((df['min_evt_time']>=0)|(df['min_evt_time'].isna()))]
    df['wave_hosp'] = df.groupby('hhidpn')['wave_hosp'].transform('min')
    df.drop(columns=['nwave','min_evt_time','evt_time'], inplace=True)
    for col in cols2:
        df.loc[df[col]==100, col] = 1
    for col in set(cols1+cols2) - set(['evt_time','oop_spend','riearnsemp','rwthh']):
        df[col] = df[col].astype('int')
    # Replace the original hh index with enumeration
    df['hhidpn'] = df.groupby(df['hhidpn']).ngroup() + 1
    df.to_csv(outdir+'/hrs.csv', index=False)

def make(outdir):
    for k in rawpaths.keys():
        globals()[k](outdir)

make('data')
