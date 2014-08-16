/*
***********************************************************************************************************************************************************
*                                                                                                                                                         *
* NS001.mq4                                                                                                                                       *
*                                                                                                                                                         *
* Copyright july, august 2014, Peter Novak ml.                                                                                                                    *
***********************************************************************************************************************************************************
*/
/* Zgodovina verzij ---------------------------------------------------------------------------------------------------------------------------------------
NS001-demo.mq4 (verzija 1.00)
   Prva verzija, ki je delovala pravilno in je bila na testu v tednu 21.07.2014 - 27.07.2014. Napak v delovanju ni bilo odkritih, res pa je, da zaradi 
   izjemno mirnega tedna ni pri�lo do nobenega pobiranja profita.

NS001-demo-01.mq4 (verzija 1.01)
   V tej verziji posku�amo nasloviti te�avo do katere pride, �e se algoritem ustavi in pusti za seboj odprte pozicije. �eleli bi, da po ponovnem zagonu
   algoritem prepozna svoje od prej odprte pozicije in ustrezno nadaljuje z izvajanjem. Re�itev bo implementirana tako, da bo algoritem ob vsaki spremembi
   svoje trenutno stanje zapisal v datoteko NS001-[ime].dat, kjer bo [ime] dodaten parameter algoritma. Po zaustavitvi bo stanje restavriral iz zapisa v
   datoteki.
   
   Algoritmu povemo, da naj se inicializira iz datoteke z vhodnim parametrom restart. �e je njegova vrednost 1 (DA), pomeni da bo algoritem poskusil 
   prebrati inicialno stanje iz datoteke z imenom NS001-[ime].dat. �e branje ne bo uspe�no, se algoritem ustavi. �e je vrednost parametra 0 (NE), pomeni
   da se bo algoritem pognal od za�etka.
   
   Poleg tega v tej verziji uvajamo tudi mehanizem za zaustavitev algoritma: �e je spremenljivka zaustavitev nastavljena na 1, potem se algoritem po
   dose�enem profitnem cilju ustavi. �e je 0, nadaljuje s trgovanjem.
--------------------------------------------------------------------------------------------------------------------------------------------------------*/



#property copyright "Peter Novak ml., M.Sc."
#property link      "http://www.marlin.si"



/* NS001
�e ena v seriji norih idej, vendar pa bi ta znala biti celo uspe�na. Vhodni parametri algoritma so naslednji:
	
	- ciljni dobi�ek (tpVrednost): vrednost v EUR pri kateri poberemo dobi�ek.
	- restart (restart): vrednost 1 pomeni da naj se algoritem inicializira na podlagi datoteke, vrednost 0 pomeni nov za�etek.
	- �tevilo pozicij (maxSteviloPozicij): �tevilo pozicij v nasprotnih smereh, ki jih odpremo.
	- velikost pozicij (velikostPozicij): velikost vsake od pozicij v lotih.
	- stop loss (stopRazdalja): standardna razdalja za stop loss, ki je obenem tudi razdalja med ravnemi.
	- zaustavitev: vrednost 1 pomeni, da se algoritem po dose�enem profitnem cilju zaustavi, vrednost 0 pa da za�ne takoj slediti nov profitni cilj.
 
	
Algoritem deluje takole:
	
	Faza I: INICIALIZACIJA
	-------------------------------------------------------------------------------------------------------------------------------------------------------------- 
	Odpre najvec maxSteviloPozicij v BUY in SELL smereh. Za vsako pozicijo v BUY ali SELL smeri nastavimo stop loss in take profit takole: 
		
		- prva pozicija ima stop loss 1*stopRazdalja,
		- druga pozicija ima stop loss 2*stopRazdalja, 
		- tretja pozicija ima stop loss 3*stopRazdalja in tako naprej do steviloPozicij

  Za�nemo z dvema pozicijama v vsako smer, vsaki� ko cena spro�i stop loss 1. ravni, �tevilo pozicij pove�amo za 1, dokler ne dose�e vrednosti
  maxSteviloPozicij.


	Faza II: SPREMLJANJE
	--------------------------------------------------------------------------------------------------------------------------------------------------------------
	Spremljanje modeliramo z uporabo DKA (deterministi�ni kon�ni avtomat) katerega opis stanj je podan spodaj. 
	
	Stanje 0 (S0)
	-------------
	--> Invariante stanja: 
	  o odprto je enako �tevilo pozicij v obe smeri, 
		o vse pozicije so �e odprte, 
		o noben stop loss se �e ni spro�il.
	
	--> Mo�ni prehodi:
		S0 --> S1: 
			o pogoj: ko se spro�i stop loss na eni od SELL pozicij
			o akcije pred prehodom:
				- popravimo trenutno vrednost izkupi�ka algoritma - dodamo vrednost pravkar zaprte pozicije
				- odpremo stop sell order s ceno vstopa enako kot je bila pri zaprti poziciji
				- odpremo dodaten stop sell order s ceno vstopa enako kot je bila pri zaprti poziciji, �e je odprto �tevilo pozicij < maxStevilo pozicij.
		S0 --> S2:
			o pogoj: ko se spro�i stop loss na eni od BUY pozicij
			o akcije pred prehodom:
				- popravimo trenutno vrednost izkupi�ka algoritma - dodamo vrednost pravkar zaprte pozicije
				- odpremo stop buy order s ceno vstopa enako kot je bila pri zaprti poziciji
				- odpremo dodaten stop buy order s ceno vstopa enako kot je bila pri zaprti poziciji, �e je odprto �tevilo pozicij < maxStevilo pozicij.
					
  Stanje 1 (S1)
  -------------
	--> Invariante stanja  
		o odprtih je ve� BUY pozicij kot SELL pozicij,
		o najmanj ena od SELL pozicij je dosegla stop loss, 
		o vrednost vseh odprtih pozicij + izkupi�ek algoritma < ciljni dobi�ek
	
	--> Mo�ni prehodi:
		S1 --> S0:
			o pogoj: ko se odprejo vsi stop sell orderji in je �tevilo odprtih pozicij v obe smeri ponovno enako,
			o akcije pred prehodom: /
		ponoven zagon algoritma INICIALIZACIJA:
			o pogoj: vrednost vseh odprtih pozicij + izkupi�ek algoritma > ciljni dobi�ek
			o akcije pred prehodom:
				- zapremo vse odprte pozicije
				- zapremo vse stop orderje

	Stanje 2 (S2)
	-------------
	--> Invariante stanja: 
		o odprtih je ve� SELL pozicij kot BUY pozicij,
		o najmanj ena od BUY pozicij je dosegla stop loss, 
		o vrednost vseh odprtih pozicij + izkupi�ek algoritma < ciljni dobi�ek
	--> Mo�ni prehodi:
		S2 --> S0:
			o pogoj: ko se odprejo vsi stop buy orderji in je �tevilo odprtih pozicij v obe smeri ponovno enako,
			o akcije pred prehodom: /
		ponoven zagon algoritma INICIALIZACIJA:
			o pogoj: vrednost vseh odprtih pozicij + izkupi�ek algoritma > ciljni dobi�ek
			o akcije pred prehodom:
				- zapremo vse odprte pozicije
				- zapremo vse stop orderje
				
	Stanje 3 (S3)
	-------------
	�akamo da nastopi �as za trgovanje
	
	Stanje 4 (S4)
	-------------
	Kon�no stanje.
*/



// Vhodni parametri ---------------------------------------------------------------------------------------------------------------------------------------
extern string imeDatoteke;       // Identifikator datoteke
extern int    maxSteviloPozicij; // Najve�je �tevilo pozicij
extern double stopRazdalja;      // Razdalja med pozicijami
extern double tpVrednost;        // Profitni cilj (EUR)
extern int    uraKonca;          // Ura za�etka trgovanja
extern int    uraZacetka;        // Ura konca trgovanja
extern int    restart;           // Restart 1 - DA, 0 - NE
extern double velikostPozicij;   // Velikost pozicij (v lotih)
extern int    zaustavitev;       // 1 - DA, 0 - NE




// Globalne konstante -------------------------------------------------------------------------------------------------------------------------------------
#define MAX_POZ 50 // najve�je mo�no �tevilo odprtih pozicij v eno smer
#define S0      10 // stanje S0
#define S1      11 // stanje S1
#define S2      12 // stanje S2
#define S3      13 // stanje S3
#define S4      14 // stanje S4
#define NAPAKA  -1
#define USPEH    1



// Globalne spremenljivke ---------------------------------------------------------------------------------------------------------------------------------
double izkupicekAlgoritma;   // trenutni izkupi�ek algoritma
int    kazOdprtaProdajna;    // kazalec na naslednjo odprto prodajno pozicijo
int    kazOdprtaNakupna;     // kazalec na naslednjo odprto nakupno pozicijo
int    nakPozicije[MAX_POZ]; // polje id-jev nakupnih pozicij
int    proPozicije[MAX_POZ]; // polje id-jev prodajnih pozicij
int    stanje;               // trenutno stanje DKA
int    steviloPozicij;       // trenutno �tevilo pozicij



/*
***********************************************************************************************************************************************************
*                                                                                                                                                         *
* GLAVNI PROGRAM in obvezne funkcije: init, deinit, start                                                                                                 *
*                                                                                                                                                         *
***********************************************************************************************************************************************************
*/



/*-------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: deinit  

Funkcionalnost:
---------------
Sistem jo pokli�e ob zaustavitvi. NS001 je ne uporablja.

Zaloga vrednosti:
-----------------
/

Vhodni parametri:
-----------------
/

Implementacija: 
--------------- */   
int deinit()
{
  return( USPEH );
} // deinit 



/*-------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: init  

Funkcionalnost:
---------------
Sistem jo pokli�e ob zagonu. V njej nastavimo za�etno stanje avtomata, za�etni izkupi�ek algoritma in izpi�emo pozdravno sporo�ilo.

Zaloga vrednosti:
-----------------
/

Vhodni parametri:
-----------------
/

Implementacija: 
--------------- */
int init()
{
  Print( "****************************************************************************************************************" );
  Print( "* Welcome on behalf of NS001, version 1.01. Let's f*** the biatch!                                             *" );
  Print( "****************************************************************************************************************" );
 
  double razdalja; 
  
  // inicializacija vseh globalnih spremenljivk
  izkupicekAlgoritma = 0;
  kazOdprtaNakupna   = 0;
  kazOdprtaProdajna  = 0;
  steviloPozicij     = 2;
	
	// �e smo algoritem restartali, potem inicializiramo algoritem na podlagi zapisa v datoteki. Po restartu postavimo restart na 0.
	if( restart == 1 )
	{ 
	   stanje = PreberiStanje( imeDatoteke );
	   if( stanje == NAPAKA ) 
	   { Print( "Inicializacija ni bila uspe�na, algoritem prekinjen - prehod v kon�no stanje S4." ); stanje = S4; return( S4 ); }
	   else
	   { restart = 0; IzbrisiDatoteko( imeDatoteke ); ShraniStanje( imeDatoteke ); return( stanje ); }
	}
	
   // �e smo izven trgovalnega �asa, potem gremo v stanje S3, sicer v S0 in odpremo za�etni nabor pozicij
   Print( "Ura: ", TimeHour( TimeCurrent() ), " Minuta: ", TimeMinute( TimeCurrent() ) );
   if( TrgovalnoObdobje() == true ) { stanje = S0; } else { Print( "Trenutno smo izven trgovalnega �asa - �akamo, da napo�i na� �as..." ); stanje = S3; return( S3 ); }
   
	// odpiranje za�etnega nabora pozicij
	razdalja = stopRazdalja;
	for( int i = 0; i < steviloPozicij; i++)
	{
		nakPozicije[ i ] = OdpriPozicijo( OP_BUY,  razdalja  ); 
		proPozicije[ i ] = OdpriPozicijo( OP_SELL, razdalja );
		razdalja = razdalja + razdalja;
		// PN: opozorilo �e pride pri odpiranju pozicije do napake - nadomestimo z bullet proof error handlingom, �e bodo testi pokazali profitabilnost
		if( ( nakPozicije[ i ] == NAPAKA ) || ( proPozicije[ i ] == NAPAKA ) ) { Print("init: NAPAKA pri odpiranju pozicije ", i ); }
	}
	
	IzbrisiDatoteko( imeDatoteke ); 
	ShraniStanje( imeDatoteke );
	return( S0 );
} // init



/*-------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: start  

Funkcionalnost:
---------------
Glavna funkcija, ki upravlja celoten algoritem - sistem jo pokli�e ob vsakem ticku. 

Zaloga vrednosti:
-----------------
/

Vhodni parametri:
-----------------
/

Implementacija: 
--------------- */
int start()
{
  int trenutnoStanje; // zabele�imo za ugotavljanje spremebe stanja
 
  trenutnoStanje = stanje;
  switch( stanje )
  {
    case S0: stanje = StanjeS0(); break;
    case S1: stanje = StanjeS1(); break;
    case S2: stanje = StanjeS2(); break;
    case S3: stanje = StanjeS3(); break;
    case S4: stanje = StanjeS4(); break;
    default:
      Print( "NS001::start::OPOZORILO: Stanje ", stanje, " ni veljavno stanje - preveri pravilnost delovanja algoritma." );
  }

  if( trenutnoStanje != stanje ) 
  { IzbrisiDatoteko( imeDatoteke ); ShraniStanje( imeDatoteke ); Print( "Prehod: ", ImeStanja( trenutnoStanje ), " -----> ", ImeStanja( stanje ) ); }
  
  return( USPEH );
} // start



/*
***********************************************************************************************************************************************************
*                                                                                                                                                         *
* POMO�NE FUNKCIJE                                                                                                                                        *
*                                                                                                                                                         *
***********************************************************************************************************************************************************
*/



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ImeStanja( int KodaStanja )

Funkcionalnost:
---------------
Na podlagi numeri�ne kode stanja, vrne opis stanja.  

Zaloga vrednosti:
-----------------
imena stanj

Vhodni parametri:
-----------------
KodaStanja: enoli�na oznaka stanja. 

Implementacija: 
--------------- */
string ImeStanja( int KodaStanja )
{
  switch( KodaStanja )
  {
    case S0: return( "S0: �akamo na vstop" );
    case S1: return( "S1: smer BUY"        );
    case S2: return( "S2: smer SELL"       );
    case S3: return( "S3: gledamo na uro"  );
    case S4: return( "S4: zaustavitev"     );
    default: return( "NS001::ImeStanja::OPOZORILO: KodaStanja ni prepoznana. Preveri pravilnost delovanja algoritma." );
  }
} // ImeStanja



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzbrisiDatoteko( string ime )

Funkcionalnost:
---------------
Na podlagi imena datoteke izbri�emo datoteko, �e obstaja. 

Zaloga vrednosti:
-----------------
USPEH

Vhodni parametri:
-----------------
identifikator datoteke

Implementacija: 
--------------- */
string IzbrisiDatoteko( string ime )
{
  string polnoIme = "NS001-" + ime + ".dat";
  
  if( FileIsExist( polnoIme ) == true ) { FileDelete( polnoIme ); } else { Print( "NS001:IzbrisiDatoteko: datoteka ", polnoIme, " ne obstaja." ); }
  return( USPEH );
} // IzbrisiDatoteko



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriNadomestnoPozicijo( int id )

Funkcionalnost:
---------------
Odpre buy ali sell stop entry order na enaki ceni kot jo ima podana pozicija, z enakim stop loss-om. 

Zaloga vrednosti:
-----------------
id odprte pozicije: �e je bilo odpiranje pozicije uspe�no;
NAPAKA: �e odpiranje pozicije ni bilo uspe�no; 

Vhodni parametri:
-----------------
id

Implementacija: 
--------------- */
int OdpriNadomestnoPozicijo( int id )
{
  bool Rezultat1; // za�asna spremenljivka za rezultat OrderSelect funkcije
  int  Rezultat2; // za�asna spremenljivka za rezultat OrderSend funkcije
 
  // poi��emo pozicijo, ki jo nadome��amo
  Rezultat1 = OrderSelect( id, SELECT_BY_TICKET );
  if( Rezultat1 == false ) { Print( "OdpriNadomestnoPozicijo::NAPAKA: pozicije z oznako ni: ", id ); return( NAPAKA ); }
  else 
    { 
      if( OrderType() == OP_BUY )  
        { Rezultat2 = OrderSend( Symbol(), OP_BUYSTOP,  velikostPozicij, OrderOpenPrice(), 0, OrderStopLoss(), 0,  "NS001", 0, 0, Green );  }
      if( OrderType() == OP_SELL ) 
        { Rezultat2 = OrderSend( Symbol(), OP_SELLSTOP, velikostPozicij, OrderOpenPrice(), 0, OrderStopLoss(), 0,  "NS001", 0, 0, Green );  }
      if( Rezultat2 == -1 ) { Print( "OdpriNadomestnoPozicijo::NAPAKA: neuspe�no odpiranje nadomestne pozicije.", id ); return( NAPAKA ); } else { return( Rezultat2 ); }
    }
} // OdpriNadomestnoPozicijo



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriDodatniUkaz( int tip, int id )

Funkcionalnost:
---------------
Odpre buy ali sell order podanega tipa na enaki ceni kot jo ima podana pozicija, s stop loss-om, ki je za en nivo ve�ji

Zaloga vrednosti:
-----------------
id odprte pozicije: �e je bilo odpiranje pozicije uspe�no;
NAPAKA: �e odpiranje pozicije ni bilo uspe�no; 

Vhodni parametri:
-----------------
id

Implementacija: 
--------------- */
int OdpriDodatniUkaz( int tip, int id )
{
  bool   Rezultat1; // za�asna spremenljivka za rezultat OrderSelect funkcije
  int    Rezultat2; // za�asna spremenljivka za rezultat OrderSend funkcije
  double stop; // stop loss razdalja
 
  // poi��emo pozicijo, ki jo nadome��amo
  Rezultat1 = OrderSelect( id, SELECT_BY_TICKET );
  if( Rezultat1 == false ) { Print( "OdpriDodatniUkaz::NAPAKA: pozicije z oznako ni: ", id ); return( NAPAKA ); }
  else 
    { 
      if( ( tip == OP_BUYLIMIT) || ( tip == OP_BUYSTOP ) ) { stop = OrderStopLoss() - stopRazdalja; } else { stop = OrderStopLoss() + stopRazdalja; }
      Rezultat2 = OrderSend( Symbol(), tip,  velikostPozicij, OrderOpenPrice(), 0, stop, 0,  "NS001", 0, 0, Green );
      if( Rezultat2 == -1 ) 
      { 
        Print( "OdpriDodatniUkaz::NAPAKA: neuspe�no odpiranje dodatne pozicije.", id ); 
        return( NAPAKA ); 
      } else 
      { return( Rezultat2 ); }
    }
} // OdpriDodatniUkaz



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriPozicijo( int Smer, double razdalja )

Funkcionalnost:
---------------
Odpre pozicijo po trenutni tr�ni ceni v podani Smeri. �e gre za pozicijo nakup (Smer OP_BUY):
* nastavi stop loss podano razdaljo to�k pod ceno odprtja;

�e gre za pozicijo prodaja (Smer OP_SELL):
* nastavi stop loss podano razdaljo to�k nad ceno odprtja.

Zaloga vrednosti:
-----------------
id odprte pozicije: �e je bilo odpiranje pozicije uspe�no;
NAPAKA: �e odpiranje pozicije ni bilo uspe�no; 

Vhodni parametri:
-----------------
Smer: OP_BUY ali OP_SELL.
razdalja: razdalja

Implementacija: 
--------------- */
int OdpriPozicijo( int Smer, double razdalja )
{
  int Rezultat;
 
  if( Smer == OP_BUY ) { Rezultat = OrderSend( Symbol(), OP_BUY,  velikostPozicij, Ask, 0, Ask - razdalja, 0, "NS001", 0, 0, Green ); }
  else                 { Rezultat = OrderSend( Symbol(), OP_SELL, velikostPozicij, Bid, 0, Bid + razdalja, 0, "NS001", 0, 0, Red   ); }
  if( Rezultat == -1 ) { return( NAPAKA ); } else { return( Rezultat ); }
} // OdpriPozicijo



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PozicijaZaprta( int Id )

Funkcionalnost:
---------------
Funkcija pove ali je pozicija s podanim Id-jem zaprta ali ne. 

Zaloga vrednosti:
-----------------
true : pozicija je zaprta.
false: pozicija je odprta.

Vhodni parametri:
-----------------
Id: oznaka pozicije.

Implementacija: 
--------------- */
bool PozicijaZaprta( int Id )
{
  int Rezultat;

  Rezultat = OrderSelect( Id, SELECT_BY_TICKET );
  if( Rezultat == false ) 
    { Print( "NS001::PozicijaZaprta::OPOZORILO: Pozicije ", Id, " ni bilo mogo�e najti. Preveri pravilnost delovanja algoritma." ); return( false ); }

  if( OrderCloseTime() == 0 ) { return( false ); } else { return( true ); }
} // PozicijaZaprta



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PreberiStanje( string ime )

Funkcionalnost:
---------------
Funkcija prebere glavne parametre algoritma iz datoteke. Vrstni red branja je naslednji:

int    maxSteviloPozicij;    // Najve�je �tevilo pozicij
double stopRazdalja;         // Razdalja med pozicijami
double tpVrednost;           // Profitni cilj (EUR)
int    uraKonca;             // Ura konca trgovanja
int    uraZacetka;           // Ura za�etka trgovanja
double velikostPozicij;      // Velikost pozicij (v lotih)
double izkupicekAlgoritma;   // trenutni izkupi�ek algoritma
int    kazOdprtaProdajna;    // kazalec na naslednjo odprto prodajno pozicijo
int    kazOdprtaNakupna;     // kazalec na naslednjo odprto nakupno pozicijo
int    stanje;               // trenutno stanje DKA
int    steviloPozicij;       // trenutno �tevilo pozicij
int    nakPozicije[MAX_POZ]; // polje id-jev nakupnih pozicij
int    proPozicije[MAX_POZ]; // polje id-jev prodajnih pozicij



Zaloga vrednosti:
-----------------
USPEH  - branje datoteke je bilo uspe�no
NAPAKA - branje datoteke ni bilo uspe�no

Vhodni parametri:
-----------------
Ime datoteke.

Implementacija: 
--------------- */
int PreberiStanje( string ime )
{
  int    rocajDatoteke;
  string polnoIme;

  polnoIme      = "NS001-" + ime + ".dat";
  
  // odpremo datoteko
  ResetLastError();
  rocajDatoteke = FileOpen( polnoIme, FILE_READ|FILE_BIN );
  
  if( rocajDatoteke != INVALID_HANDLE)
  {
    Print( "Branje stanja algoritma iz datoteke ", polnoIme, ": " );
    Print( "----------------------------------------" );
    maxSteviloPozicij  = FileReadInteger( rocajDatoteke,    INT_VALUE );
    Print( "Najve�je �tevilo pozicij [maxSteviloPozicij]: ",       maxSteviloPozicij );
    stopRazdalja       = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    Print( "Razdalja med pozicijami [stopRazdalja]: ",                  stopRazdalja );
    tpVrednost         = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    Print( "Profitni cilj (EUR) [tpVrednost]: ",                          tpVrednost );
    uraKonca           = FileReadInteger( rocajDatoteke, INT_VALUE    );
    Print( "Ura konca trgovanja [uraKonca]: ",                              uraKonca );
    uraZacetka         = FileReadInteger( rocajDatoteke, INT_VALUE    );
    Print( "Ura za�etka trgovanja [uraZacetka]: ",                        uraZacetka );
    velikostPozicij    = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    Print( "Velikost pozicij (v lotih) [velikostPozicij]: ",         velikostPozicij );
    izkupicekAlgoritma = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    Print( "Trenutni izkupi�ek algoritma [izkupicekAlgoritma]: ", izkupicekAlgoritma );
    kazOdprtaProdajna  = FileReadInteger( rocajDatoteke, INT_VALUE    );
    Print( "Kazalec na odprto prodajno [kazOdprtaProdajna]: ",     kazOdprtaProdajna );
    kazOdprtaNakupna   = FileReadInteger( rocajDatoteke, INT_VALUE    );
    Print( "Kazalec na odprto nakupno [kazOdprtaNakupna]: ",        kazOdprtaNakupna );
    stanje             = FileReadInteger( rocajDatoteke, INT_VALUE    );
    Print( "Stanje algoritma [stanje]: ",                                     stanje );
    steviloPozicij     = FileReadInteger( rocajDatoteke, INT_VALUE    );
    Print( "Trenutno �tevilo pozicij [steviloPozicij]: ",             steviloPozicij );
        
    // polji nakupnih in prodajnih pozicij
    Print( "Nakupne pozicije: " );
    for( int i = 0; i < MAX_POZ; i++ )
    {
      nakPozicije[ i ] = FileReadInteger( rocajDatoteke, INT_VALUE ); 
      Print( nakPozicije[ i ] ); 
    }
    Print( "Prodajne pozicije: " );
    for( int j = 0; j < MAX_POZ; j++ )
    {
      proPozicije[ j ] = FileReadInteger( rocajDatoteke, INT_VALUE ); 
      Print( proPozicije[ j ] );
    }
 
    FileClose( rocajDatoteke );
    return( stanje );
  }
  else 
  { 
    PrintFormat( "Napaka pri odpiranju datoteke: %s. Koda napake = %d", polnoIme, GetLastError() );
    return( NAPAKA ); 
  } 
} // PreberiStanje



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ShraniStanje( string ime )

Funkcionalnost:
---------------
Funkcija shrani vse glavne parametre algoritma v datoteko. Vrstni red shranjevanja stanja je naslednji:

int    maxSteviloPozicij;    // Najve�je �tevilo pozicij
double stopRazdalja;         // Razdalja med pozicijami
double tpVrednost;           // Profitni cilj (EUR)
int    uraKonca;             // Ura konca trgovanja
int    uraZacetka;           // Ura za�etka trgovanja
double velikostPozicij;      // Velikost pozicij (v lotih)
double izkupicekAlgoritma;   // trenutni izkupi�ek algoritma
int    kazOdprtaProdajna;    // kazalec na naslednjo odprto prodajno pozicijo
int    kazOdprtaNakupna;     // kazalec na naslednjo odprto nakupno pozicijo
int    stanje;               // trenutno stanje DKA
int    steviloPozicij;       // trenutno �tevilo pozicij
int    nakPozicije[MAX_POZ]; // polje id-jev nakupnih pozicij
int    proPozicije[MAX_POZ]; // polje id-jev prodajnih pozicij



Zaloga vrednosti:
-----------------
USPEH  - odpiranje datoteke je bilo uspe�no
NAPAKA - odpiranje datoteke ni bilo uspe�no

Vhodni parametri:
-----------------
Ime datoteke.

Implementacija: 
--------------- */
int ShraniStanje( string ime )
{
  int    rocajDatoteke;
  string polnoIme;

  polnoIme      = "NS001-" + ime + ".dat";
  rocajDatoteke = FileOpen( polnoIme, FILE_WRITE|FILE_BIN );
  
  if( rocajDatoteke != INVALID_HANDLE)
  {
    Print( "Zapisovanje stanja algoritma v datoteko", polnoIme, ": " );
    Print( "----------------------------------------" );
    Print( "Najve�je �tevilo pozicij [maxSteviloPozicij]: ",       maxSteviloPozicij );
    FileWriteInteger( rocajDatoteke,                               maxSteviloPozicij );
    Print( "Razdalja med pozicijami [stopRazdalja]: ",                  stopRazdalja );
    FileWriteDouble ( rocajDatoteke,                                    stopRazdalja );
    Print( "Profitni cilj (EUR) [tpVrednost]: ",                          tpVrednost );
    FileWriteDouble ( rocajDatoteke,                                      tpVrednost );
    Print( "Ura konca trgovanja [uraKonca]: ",                              uraKonca );
    FileWriteInteger( rocajDatoteke,                                        uraKonca );
    Print( "Ura za�etka trgovanja [uraZacetka]: ",                        uraZacetka );
    FileWriteInteger( rocajDatoteke,                                      uraZacetka );
    Print( "Velikost pozicij (v lotih) [velikostPozicij]: ",         velikostPozicij );
    FileWriteDouble ( rocajDatoteke,                                 velikostPozicij );
    Print( "Trenutni izkupi�ek algoritma [izkupicekAlgoritma]: ", izkupicekAlgoritma );
    FileWriteDouble ( rocajDatoteke,                              izkupicekAlgoritma );
    Print( "Kazalec na odprto prodajno [kazOdprtaProdajna]: ",     kazOdprtaProdajna );
    FileWriteInteger( rocajDatoteke,                               kazOdprtaProdajna );
    Print( "Kazalec na odprto nakupno [kazOdprtaNakupna]: ",        kazOdprtaNakupna );
    FileWriteInteger( rocajDatoteke,                                kazOdprtaNakupna );
    Print( "Stanje algoritma [stanje]: ",                                     stanje );
    FileWriteInteger( rocajDatoteke,                                          stanje );
    Print( "Trenutno �tevilo pozicij [steviloPozicij]: ",             steviloPozicij );
    FileWriteInteger( rocajDatoteke,                                  steviloPozicij );
    
    // polji nakupnih in prodajnih pozicij
    Print( "Nakupne pozicije: " );
    for( int i = 0; i < MAX_POZ; i++ )
    {
      Print( nakPozicije[ i ] );
      FileWriteInteger( rocajDatoteke, nakPozicije[ i ] ); 
    }
    Print( "Prodajne pozicije: " );
    for( int j = 0; j < MAX_POZ; j++ )
    {
      Print( proPozicije[ j ] );
      FileWriteInteger( rocajDatoteke, proPozicije[ j ] ); 
    }
 
    FileClose( rocajDatoteke );
    return( USPEH );
  }
  else { Print( "NS001:ShraniStanje: Napaka pri shranjevanju stanja algoritma. Preveri pravilnost delovanja!" ); return( NAPAKA ); } 
} // ShraniStanje



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: TrgovalnoObdobje()

Funkcionalnost:
---------------
Ugotovi ali je trenutni �as znotraj trgovalnega intervala, dolo�enega z vhodnimi parametri algoritma.

Zaloga vrednosti:
-----------------
true : ura je znotraj intervala
false: ura je zunaj intervala

Vhodni parametri:
-----------------
/

Implementacija: 
--------------- */
bool TrgovalnoObdobje()
{
  datetime cas;
  int      trenutnaUra;
  
  cas            = TimeCurrent();
  trenutnaUra    = TimeHour( cas );
  
  if( ( trenutnaUra    >= uraZacetka    ) && 
      ( trenutnaUra    <= uraKonca      ) ) 
      { return( true ); } else { return( false ); }
  
} // TrgovalnoObdobje



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: UkazOdprt( int Id )

Funkcionalnost:
---------------
Funkcija pove ali je ukaz s podanim Id-jem odprta pozicija ali ne. 

Zaloga vrednosti:
-----------------
true : ukaz je odprta pozicija
false: ukaz ni odprta pozicija

Vhodni parametri:
-----------------
Id: oznaka pozicije.

Implementacija: 
--------------- */
bool UkazOdprt( int Id )
{
  int Rezultat;
  int tip;

  Rezultat = OrderSelect( Id, SELECT_BY_TICKET );
  if( Rezultat == false ) 
    { Print( "NS001::UkazOdprt::OPOZORILO: Pozicije ", Id, " ni bilo mogo�e najti. Preveri pravilnost delovanja algoritma." ); return( false ); }

  tip = OrderType();
  if( ( ( tip == OP_BUY) || ( tip == OP_SELL ) ) &&
      ( OrderCloseTime() == 0 ) ) { return( true ); } else { return( false ); }
} // Ukaz odprt



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VrednostPozicije( int Id )

Funkcionalnost:
---------------
Vrne vrednost pozicije z oznako Id.

Zaloga vrednosti:
-----------------
vrednost pozicije v EUR; 

Vhodni parametri:
-----------------
Id: oznaka pozicije.

Implementacija: 
--------------- */
double VrednostPozicije( int Id )
{
  int Rezultat;

  Rezultat = OrderSelect( Id, SELECT_BY_TICKET );
  if( Rezultat == false ) 
    { Print( "NS001::ZapriPozicijo::OPOZORILO: Pozicije ", Id, " ni bilo mogo�e najti. Preveri pravilnost delovanja algoritma." ); return( 0 ); }
  return( OrderProfit() );
} // VrednostPozicije



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VrednostOdprtihPozicij()

Funkcionalnost:
---------------
Vrne vsoto vrednosti vseh odprtih pozicij.

Zaloga vrednosti:
-----------------
vsota vrednosti odprtih pozicij v EUR; 

Vhodni parametri:
-----------------
/
Uporablja globalne spremenljivke.

Implementacija: 
--------------- */
double VrednostOdprtihPozicij()
{
  double vrednost = 0;

  for( int i = kazOdprtaNakupna;  i < steviloPozicij; i++ ) { vrednost = vrednost + VrednostPozicije( nakPozicije[ i ] ); }
  for( int j = kazOdprtaProdajna; j < steviloPozicij; j++ ) { vrednost = vrednost + VrednostPozicije( proPozicije[ j ] ); }
  return( vrednost );
} // VrednostOdprtihPozicij



/*------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ZapriPozicijo( int Id )

Funkcionalnost:
---------------
Zapre pozicijo z oznako Id po trenutni tr�ni ceni.

Zaloga vrednosti:
-----------------
true: �e je bilo zapiranje pozicije uspe�no;
false: �e zapiranje pozicije ni bilo uspe�no; 

Vhodni parametri:
-----------------
Id: oznaka pozicije.
Smer: vse mo�ne variante, bri�e tudi ukaze

Implementacija: 
--------------- */
bool ZapriPozicijo( int Id )
{
  int Rezultat;

  Rezultat = OrderSelect( Id, SELECT_BY_TICKET );
  if( Rezultat == false ) 
    { Print( "NS001::ZapriPozicijo::OPOZORILO: Pozicije ", Id, " ni bilo mogo�e najti. Preveri pravilnost delovanja algoritma." ); return( false ); }

  switch( OrderType() )
  {
    case OP_BUY:
      return( OrderClose( Id, OrderLots(), Bid, 0, Red ) );
    case OP_SELL:
      return( OrderClose( Id, OrderLots(), Ask, 0, Red ) );
    default:
      return( OrderDelete( Id ) );
  }  
} // ZapriPozicijo


/*
***********************************************************************************************************************************************************
*                                                                                                                                                         *
* FUNKCIJE DKA                                                                                                                                            *
*                                                                                                                                                         *
***********************************************************************************************************************************************************
*/



/*-------------------------------------------------------------------------------------------------------------------------------------------------------
	Stanje 0 (S0)
	-------------
	--> Invariante stanja: 
	  o odprto je enako �tevilo pozicij v obe smeri, 
		o vse pozicije so �e odprte, 
		o noben stop loss se �e ni spro�il.
	
	--> Mo�ni prehodi:
		S0 --> S1: 
			o pogoj: ko se spro�i stop loss na eni od SELL pozicij
			o akcije pred prehodom:
				- popravimo trenutno vrednost izkupi�ka algoritma - dodamo vrednost pravkar zaprte pozicije
				- odpremo stop sell order s ceno vstopa enako kot je bila pri zaprti poziciji
				- odpremo dodaten stop sell order s ceno vstopa enako kot je bila pri zaprti poziciji, �e je odprto �tevilo pozicij < maxStevilo pozicij.
		S0 --> S2:
			o pogoj: ko se spro�i stop loss na eni od BUY pozicij
			o akcije pred prehodom:
				- popravimo trenutno vrednost izkupi�ka algoritma - dodamo vrednost pravkar zaprte pozicije
				- odpremo stop buy order s ceno vstopa enako kot je bila pri zaprti poziciji
				- odpremo dodaten stop buy order s ceno vstopa enako kot je bila pri zaprti poziciji, �e je odprto �tevilo pozicij < maxStevilo pozicij.
*/
int StanjeS0()
{
  // S0 --> S1
  // pozicije so v polju proPozicije urejene po vrsti, �e se je spro�il SL, se je spro�il na prvi odprti prodajni poziciji
  if( PozicijaZaprta( proPozicije[ kazOdprtaProdajna ] ) == true ) 
    { 
      // popravimo znesek izkupi�ka algoritma in odpremo nadomestni sell stop order
      Print("Prodajna pozicija ", kazOdprtaProdajna, " z id-jem ", proPozicije[ kazOdprtaProdajna ], " zaprta - izpolnjen pogoj za prehod v smer nakupa (S1)." );
      izkupicekAlgoritma = izkupicekAlgoritma + VrednostPozicije( proPozicije[ kazOdprtaProdajna ] ); 
      Print("Trenutni izkupi�ek algoritma: ", DoubleToStr( izkupicekAlgoritma, 2 ), " EUR" );
      proPozicije[ kazOdprtaProdajna ] = OdpriNadomestnoPozicijo( proPozicije[ kazOdprtaProdajna ] ); 
      if( proPozicije[ kazOdprtaProdajna ] == NAPAKA ) { Print("NAPAKA:S0: Odpiranje nadomestne prodajne pozicije neuspe�no." ); }
      kazOdprtaProdajna++; 
      
      // �e �tevilo pozicij �e ni doseglo maksimuma, potem ga pove�amo za ena in dodamo po en dodatni stop order v vsako smer
      if( steviloPozicij < maxSteviloPozicij )
        { 
          // indeks steviloPozicij - 1 vedno ka�e na pozicijo z najve�jim stop loss-om
          proPozicije[ steviloPozicij ] = OdpriDodatniUkaz( OP_SELLSTOP, proPozicije[ steviloPozicij - 1 ] );
          nakPozicije[ steviloPozicij ] = OdpriDodatniUkaz( OP_BUYLIMIT, nakPozicije[ steviloPozicij - 1 ] );
          if( ( nakPozicije[ steviloPozicij ] == NAPAKA ) ||
              ( proPozicije[ steviloPozicij ] == NAPAKA ) ) { Print( "NAPAKA:S0: Odpiranje dodatnih pozicij neuspe�no." ); }
          steviloPozicij++;
        }
      return( S1 ); 
    } 
  
  // S0 --> S2 
  // pozicije so v polju nakPozicije urejene po vrsti, �e se je spro�il SL, se je spro�il na prvi odprti nakupni poziciji
  if( PozicijaZaprta( nakPozicije[ kazOdprtaNakupna ] ) == true ) 
    { 
      // popravimo znesek izkupi�ka algoritma in odpremo nadomestni sell stop order
      Print("Nakupna pozicija ", kazOdprtaNakupna, " z id-jem ", nakPozicije[ kazOdprtaNakupna ], " zaprta - izpolnjen pogoj za prehod v smer prodaje (S2)." );
      izkupicekAlgoritma = izkupicekAlgoritma + VrednostPozicije( nakPozicije[ kazOdprtaNakupna ] ); 
      Print("Trenutni izkupi�ek algoritma: ", DoubleToStr( izkupicekAlgoritma, 2 ), " EUR" );
      nakPozicije[ kazOdprtaNakupna ] = OdpriNadomestnoPozicijo( nakPozicije[ kazOdprtaNakupna ] ); 
      kazOdprtaNakupna++; 
      
      // �e �tevilo pozicij �e ni doseglo maksimuma, potem ga pove�amo za ena in dodamo po en nadomestni stop order v vsako smer
      if( steviloPozicij < maxSteviloPozicij )
        { 
          proPozicije[ steviloPozicij ] = OdpriDodatniUkaz( OP_SELLLIMIT, proPozicije[ steviloPozicij - 1 ] );
          nakPozicije[ steviloPozicij ] = OdpriDodatniUkaz( OP_BUYSTOP,   nakPozicije[ steviloPozicij - 1 ] );
          if( ( nakPozicije[ steviloPozicij ] == NAPAKA ) ||
              ( proPozicije[ steviloPozicij ] == NAPAKA ) ) { Print( "NAPAKA: Odpiranje dodatnih pozicij neuspe�no." ); }
          steviloPozicij++;
        }
      return( S2 ); 
    }   
  
  return( S0 );   

} // StanjeS0



/*-------------------------------------------------------------------------------------------------------------------------------------------------------
Stanje S1
---------
Stanje 1 (S1)
	- Invariante stanja: 
		- odprtih je ve� BUY pozicij kot SELL pozicij,
		- najmanj ena od SELL pozicij je dosegla stop loss, 
		- vrednost vseh odprtih pozicij + izkupi�ek algoritma < ciljni dobi�ek
	- Mo�ni prehodi:
		- prehod v stanje S0:
			- pogoj: ko se odprejo vsi stop sell orderji in je �tevilo odprtih pozicij v obe smeri ponovno enako,
			- akcije pred prehodom: /
		- prehod v Fazo INICIALIZACIJA:
			- pogoj: vrednost vseh odprtih pozicij + izkupi�ek algoritma > ciljni dobi�ek
			- akcije pred prehodom:
				- zapremo vse odprte pozicije
*/
int StanjeS1()
{
  // prehod v fazo INICIALIZACIJA
  double vrednost = VrednostOdprtihPozicij();
  if( ( vrednost + izkupicekAlgoritma ) > tpVrednost ) 
  { 
    for( int i = kazOdprtaNakupna;  i < steviloPozicij; i++ ) { ZapriPozicijo( nakPozicije[ i ] ); }
    for( int j = 0;                 j < steviloPozicij; j++ ) { ZapriPozicijo( proPozicije[ j ] ); }  // ker moramo po�istiti nadomestne sell orderje
    Print( "Vrednost odprtih pozicij: ", DoubleToStr( vrednost, 2 ) );
    Print( "Izkupi�ek algoritma: ",      DoubleToStr( izkupicekAlgoritma, 2 ) );
    Print( "We f***** the biatch!!!! ------------------------------------------------------------------------------------------------------------" );
    // �e je nastavljen parameter za zaustavitev gremo v stanje S4, sicer za�nemo vse od za�etka
    if( zaustavitev == 1 ) { return( S4 ); } else { return( init() ); }
  }
  
  // S1 --> S0
  if( UkazOdprt( proPozicije[ 0 ] ) == true )
  {
    Print( "Prodajne pozicije so spet vse odprte, prehod v S0" );
    kazOdprtaProdajna = 0;
    return( S0 );
  } 
  
  // �e se je zaprla �e kak�na od prodajnih pozicij, popravimo vrednost kazalca na naslednjo odprto pozicijo, dodamo nadomesten ukaz in popravimo izkupi�ek
  if( ( kazOdprtaProdajna < steviloPozicij ) && 
      (  PozicijaZaprta( proPozicije[ kazOdprtaProdajna ] ) == true ) )
  {
    Print( "Zaprta prodajna pozicija ", kazOdprtaProdajna, " z id-jem ", proPozicije[ kazOdprtaProdajna ] );
    izkupicekAlgoritma = izkupicekAlgoritma + VrednostPozicije( proPozicije[ kazOdprtaProdajna ] );
    Print( "Izkupi�ek algoritma: ",      DoubleToStr( izkupicekAlgoritma, 2 ) );
    proPozicije[ kazOdprtaProdajna ] = OdpriNadomestnoPozicijo( proPozicije[ kazOdprtaProdajna ] );
    kazOdprtaProdajna++;
    IzbrisiDatoteko( imeDatoteke );
    ShraniStanje   ( imeDatoteke );
  }
  return( S1 );
} // StanjeS1



/*-------------------------------------------------------------------------------------------------------------------------------------------------------
Stanje S2
---------
	Stanje 2 (S2)
	-------------
	--> Invariante stanja: 
		o odprtih je ve� SELL pozicij kot BUY pozicij,
		o najmanj ena od BUY pozicij je dosegla stop loss, 
		o vrednost vseh odprtih pozicij + izkupi�ek algoritma < ciljni dobi�ek
	--> Mo�ni prehodi:
		S2 --> S0:
			o pogoj: ko se odprejo vsi stop buy orderji in je �tevilo odprtih pozicij v obe smeri ponovno enako,
			o akcije pred prehodom: /
		ponoven zagon algoritma INICIALIZACIJA:
			o pogoj: vrednost vseh odprtih pozicij + izkupi�ek algoritma > ciljni dobi�ek
			o akcije pred prehodom:
				- zapremo vse odprte pozicije
				- zapremo vse stop orderje
*/
int StanjeS2()
{
  // prehod v fazo INICIALIZACIJA
  double vrednost = VrednostOdprtihPozicij();
  if( ( vrednost + izkupicekAlgoritma ) > tpVrednost ) 
  { 
    for( int i = 0;                 i < steviloPozicij; i++ ) { ZapriPozicijo( nakPozicije[ i ] ); } // ker moramo po�istiti nadomestne buy orderje
    for( int j = kazOdprtaProdajna; j < steviloPozicij; j++ ) { ZapriPozicijo( proPozicije[ j ] ); }
    Print( "Vrednost odprtih pozicij: ", DoubleToStr( vrednost, 2 ) );
    Print( "Izkupi�ek algoritma: ",      DoubleToStr( izkupicekAlgoritma, 2 ) );
    Print( "We f***** the biatch!!!! ------------------------------------------------------------------------------------------------------------" );
    // �e je nastavljen parameter za zaustavitev gremo v stanje S4, sicer za�nemo vse od za�etka
    if( zaustavitev == 1 ) { return( S4 ); } else { return( init() ); }
  }
  
  // S2 --> S0
  if( UkazOdprt( nakPozicije[ 0 ] ) == true )
  {
    Print( "Nakupne pozicije so spet vse odprte, prehod v S0" );
    kazOdprtaNakupna = 0;
    return( S0 );
  } 
  
  // �e se je zaprla �e kak�na od nakupnih pozicij, popravimo vrednost kazalca na naslednjo odprto pozicijo, dodamo nadomesten ukaz in popravimo izkupi�ek
  if ( ( kazOdprtaNakupna < steviloPozicij ) &&
       ( PozicijaZaprta( nakPozicije[ kazOdprtaNakupna ] ) == true ) )
  {
    Print( "Zaprta nakupna pozicija ", kazOdprtaNakupna, " z id-jem ", nakPozicije[ kazOdprtaNakupna ] );
    izkupicekAlgoritma = izkupicekAlgoritma + VrednostPozicije( nakPozicije[ kazOdprtaNakupna ] );
    Print( "Izkupi�ek algoritma: ",      DoubleToStr( izkupicekAlgoritma, 2 ) );
    nakPozicije[ kazOdprtaNakupna ] = OdpriNadomestnoPozicijo( nakPozicije[ kazOdprtaNakupna ] );
    kazOdprtaNakupna++;
    IzbrisiDatoteko( imeDatoteke );
    ShraniStanje   ( imeDatoteke );
  }
  return( S2 );
} // StanjeS2



/*-------------------------------------------------------------------------------------------------------------------------------------------------------
Stanje S3
---------
	Stanje 3 (S3)
	-------------
	�akamo da nastopi �as za trgovanje
*/
int StanjeS3()
{
// �e smo izven trgovalnega �asa, potem gremo v stanje S3, sicer v S0 in odpremo za�etni nabor pozicij
   if( TrgovalnoObdobje() == true ) { Print( "�as je, lotimo se dela..." ); init(); return( S0 ); } else { return( S3 ); }
} // StanjeS3



/*-------------------------------------------------------------------------------------------------------------------------------------------------------
Stanje S4
---------
	Stanje 4 (S4)
	-------------
	Kon�no stanje - iz tega stanja ni nobenih prehodov ve�.
*/
int StanjeS4()
{
   return( S4 );
} // StanjeS4