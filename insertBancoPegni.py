import random
import string
from datetime import datetime
from random import randrange
from datetime import timedelta

####################definizione di funzioni###########################

def random_datetime(start, end):
    delta = end - start
    int_delta = (delta.days * 24 * 60 * 60) + delta.seconds
    random_second = randrange(int_delta)
    return start + timedelta(seconds=random_second)

def rand_datetime():
    d1 = datetime.strptime('1/1/2022 1:30 PM',  '%m/%d/%Y %I:%M %p')
    d2 = datetime.strptime('5/1/2022 4:50 AM', '%m/%d/%Y %I:%M %p')
    return str(random_datetime(d1, d2))

def rand_date():
    return str(rand_datetime())[:10]

def rand_phone():
    ret = "+39 "
    for i in range(8):
        ret+= str(random.randint(0, 9))
    return ret

def rand_email(nome, cognome):
    s= nome.lower() + "." + cognome.lower() + "@" + random.choice(indirizzi)
    return s

def rand_set(a):
    return str(random.choice(a))

def rand_float(a ,b):
    return str( round(random.uniform(a, b), 2))

def rand_descrizione(tipo):
     return rand_set(descrizioni) + tipo.lower() + " proveniente dal continente " + random.choice(continenti) + " del " + str(random.randint(1, 21)) + " secolo."

#################definizione dei dati#########################################

campi = ["Musica", "Memorabilia", "Monete", "Gioielli", "Pietre preziose", "Quadri", "Motori",
         "Videogiochi", "Armi", "Arte", "Elettronica",
         "Libri", "Oro", "Argento", "Collane", "Vestiti", "Orologi"]

indirizzi = ["yahoo.com", "gmail.com", "hotmail.it", "dundermifflin.com", "outlook.com"]

nomi = ["Riccardo", "Giacomo", "Giovanni", "Jack", "Johnny", "Elena", "Federico", 
        "Valentino", "Claudia", "Michael", "Dwight", "Jim", "Oscar", "Pamela", "Petra", "Ludovica",
        "Walter", "Andrea", "Alice", "Beatrice", "Francesco", "Mariano", "Rene", "Stanis", "Gregory", "Cesare",
        "Violetta", "Francesca", "Alfredo", "Giuseppe", "Roberto", "Lorenzo", "Emiliano", "Enrico", "Mattia",
        "Yuri", "Stefano", "Paolo", "Harry", "Kyle", "Chad", "Ottone", "Renato", "Giosue", "Amerigo",
        "Diana", "Maria", "Alessia", "Felicia", "Anna", "Annabelle", "Daniele", "Marco", "Jane", "James",
        "Angelo", "Amilcare", "Nello", "Tommaso", "Chiara", "Carlo", "Kenny", "Joe", "Henry", "Sara", "Rick",
        "Les", "Chumlee", "Alan"]

cognomi = ["Rossi", "Neri", "Bianchi", "Greco", "Annunziato", "Ferretti", "House", "LaRochelle", "Verdi",
            "Viola", "Smith", "White", "Giusti", "Russo", "Costa", "Ferrari", "Lamborghini", "Gallo",
            "Fontana", "Scott", "Barbieri", "Briatore", "Berlusconi", "Bruno", "Galilei", "Conte", "Draghi",
            "Ferrero", "Depp", "Heard", "Lauro", "Deledda", "Amato", "DeSantis", "Augusto", "Carli", "Doe", 
            "Amici", "Franco", "Basettoni", "Topolini", "Paperini", "Torino", "Romano", "Svevo", "Alberti",
            "Sette", "Colombo", "Marino","Gatti", "Gatto", "Esposito", "Leone", "Longo", "Grande", "Grandi",
            "Gentile", "Gentili", "Moretti", "Ferri", "Testa", "Ferro", "Amico", "Pennac", "Miele", "Mieli",
            "Bravo", "Bravi", "Bastianich", "Milano", "Londra", "Parisi", "Fermi", "Rossoni", "Nerone",
            "Corte", "Gambini", "Collina", "Monti", "Buttazzoni", "Violini", "Piano", "Scorta", "Scavo", 
            "Harrison", "Lennon", "Starr", "Gold", "McCartney", "Jagger", "Orto", "Hortis", "Foscolo", "Alighieri"]
reparti = ["Vendite", "Pegni", "HR"]

descrizioni = ["Un bel modello di ", "Un gran esempio di ", "Tra i più costosi esemplari di ", "Un emblema di ",
                "Un ottimo particolare di ", "Un significativo esemplare di ", "Un eccelso campione di ",
                "Un sublime pezzo di ", "Tra i più rari pezzi di ", "Un unico modello di " ]

continenti = ["europeo", "asiatico", "africano", "oceanico", "americano", "antartico"]

n_esperti = 50
n_dipendenti = 20
n_scontrini = 100
n_transazioni = n_scontrini
n_beni = 300
n_debitori = 80
n_valutazioni = 100
n_prestiti = 100

fk_esperti = []
fk_scontrini = list(range(1, n_scontrini+1))
fk_prodotti = []
fk_scontrini = list(range(1, n_scontrini+1))
fk_prestiti = []

########################stampa delle query################################


for i in range(1, n_esperti+1):
    e_telefono = rand_phone()
    fk_esperti.append(e_telefono)
    e_nome = rand_set(nomi) 
    e_cognome = rand_set(cognomi) 
    e_email = rand_email(e_nome, e_cognome)
    e_campo = rand_set(campi)
    e_costo = rand_float(1, 50)
    print("INSERT INTO esperti VALUES(" 
            + "'" +e_telefono + "'" + ", "
            + "'" + e_email + "'" + ", "
            + "'" + e_nome + "'" + ", "
            + "'" + e_cognome + "'" + ", "
            + "'" + e_campo + "'" +", "
            + e_costo + ");")

for i in range(1, n_debitori+1):
    deb_codice = str(0)
    deb_nome = rand_set(nomi)
    deb_cognome = rand_set(cognomi)
    deb_telefono = rand_phone()
    deb_email = rand_email(deb_nome, deb_cognome)
    print("INSERT INTO debitori VALUES(" 
            + deb_codice + ", "
            +"'" + deb_nome + "'" +", "
            + "'" +deb_cognome +"'" + ", "
            + "'" +deb_telefono + "'" +", "
            + "'" +deb_email+"'" + ");")
    
for i in range(1, n_dipendenti+1):
    dip_idAziendale = str(0)
    dip_nome = rand_set(nomi)
    dip_cognome = rand_set(cognomi)
    dip_reparto = rand_set(reparti)
    print("INSERT INTO dipendenti VALUES(" 
            + dip_idAziendale + ", "
            + "'" +dip_nome+"'" + ", "
            + "'" +dip_cognome+"'" + ", "
            + "'" +dip_reparto +"'" + ");")
    

for i in range(1, n_scontrini+1):
    s_numero = str(0)
    s_data = rand_date()
    if(random.uniform(0,10) > 3 ):
        s_tipo = "A"
    else:
        s_tipo = "V"
    s_esecutore = str(random.randint(1, n_dipendenti))
    print("INSERT INTO scontrini VALUES(" 
            + s_numero + ", "
            + "'" + s_data +"'" + ", "
            + "'" + s_tipo + "'" +", "
            +  s_esecutore + ");")

for i in range(1, n_prestiti+1):
    p_num = str(0)
    p_data = rand_date()
    p_durata = str(random.randint(1,180))
    p_somma = str(random.uniform(50, 50000))
    p_interesse = str(random.uniform(1,10))
    if(random.uniform(0,10) > 3 ):
        p_rinnovo = str(0)
    else:
        p_rinnovo = str(random.randint(10, 40))
    p_debitore = str(random.randint(1, n_debitori))
    p_responsabile = str(random.randint(1, n_dipendenti))
    fk_prestiti.append(str(i))
    print("INSERT INTO prestiti VALUES(" 
            + p_num + ", "
            + "'" +p_data +"'" + ", "
            + p_durata + ", "
            + p_somma + ", "
            + p_interesse + ", "
            + p_rinnovo + ", "
            + p_debitore + ", "
            + p_responsabile + ");")

for i in range(1, n_beni+1):
    b_id = str(0)
    b_tipo = rand_set(campi)
    b_descrizione = rand_descrizione(b_tipo)
    b_peso = rand_float(0.1, 10)
    if(random.uniform(0,10) > 4 ):
        b_prezzo = rand_float(50, 50000)
        b_lotto = "NULL"
        fk_prodotti.append(i)
        b_acquisito = "1"
        b_prestito = "NULL"
    else:
        b_prezzo = "NULL"
        b_lotto = str(random.randint(1,10))
        b_acquisito = "0"
        if(len(fk_prestiti) != 0):
            temp = random.choice(fk_prestiti)
            b_prestito = temp
            fk_prestiti.remove(temp)
        else:
            b_prestito = str(random.randint(1, n_prestiti))
            
    print("INSERT INTO beni VALUES(" 
            + b_id + ", "
            + "'" +b_descrizione +"'" + ", "
            + "'" +b_tipo +"'" + ", "
            + b_prezzo + ", "
            + b_peso + ", "
            + b_lotto + ", "
            + b_prestito + ", "
            + b_acquisito + ");")

for i in range(1, n_valutazioni+1):
    v_esperto = random.choice(fk_esperti)
    v_bene = str(random.randint(1, n_beni))
    v_data = rand_date()
    v_valore = rand_float(1, 10000)
    print("INSERT INTO valutazioni VALUES(" 
            + "'"+ v_esperto + "'"+ ", "
            + v_bene + ", "
            + "'" +v_data +"'" + ", "
            + v_valore + ");")

for i in range(1, n_transazioni+1):
    temp = random.choice(fk_scontrini)
    t_scontrino = str(temp)
    fk_scontrini.remove(temp)
    temp = random.choice(fk_prodotti)
    t_prodotto = str(temp)
    fk_prodotti.remove(temp)
    t_importo = rand_float(50, 50000)
    print("INSERT INTO transazioni VALUES(" 
            + t_prodotto + ", "
            + t_scontrino + ", "
            + t_importo + ");")
