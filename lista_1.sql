-- zad 1

SELECT IMIE_WROGA "WROG", OPIS_INCYDENTU "PRZEWINA"
FROM WROGOWIE_KOCUROW
WHERE DATA_INCYDENTU BETWEEN '2009-01-01' AND '2009-12-31';

-- zad 2

SELECT IMIE, FUNKCJA, W_STADKU_OD "Z NAMI OD"
FROM KOCURY
WHERE PLEC = 'D'
  AND W_STADKU_OD BETWEEN '2005-09-01' AND '2007-07-31';

-- zad 3

SELECT IMIE_WROGA "WROG", GATUNEK, STOPIEN_WROGOSCI "STOPIEN WROGOSCI"
FROM Wrogowie
WHERE LAPOWKA IS NULL
ORDER BY STOPIEN_WROGOSCI;

-- zad 4

SELECT IMIE || ' zwany ' || PSEUDO || ' (fun. ' || FUNKCJA || ') lowi myszki w bandzie' || NR_BANDY
           || ' od ' || TO_CHAR(W_STADKU_OD, 'YYYY-MM-DD') "WSZYSTKO O KOCURACH"
FROM KOCURY
WHERE PLEC = 'M'
ORDER BY W_STADKU_OD DESC, PSEUDO;

-- zad 5

SELECT PSEUDO,
       REGEXP_REPLACE(REGEXP_REPLACE(PSEUDO, 'A', '#', 1, 1), 'L', '%', 1, 1)
           "Po wymianie A na # oraz L na %"
FROM KOCURY
WHERE PSEUDO LIKE '%A%L%'
   OR PSEUDO LIKE '%L%A%';


-- zad 6

SELECT IMIE,
       W_STADKU_OD                  "W stadku",
       ROUND(PRZYDZIAL_MYSZY / 1.1) "Zjadal",
       ADD_MONTHS(W_STADKU_OD, 6)   "Podwyzka",
       PRZYDZIAL_MYSZY              "Zjada"
FROM KOCURY
WHERE MONTHS_BETWEEN(SYSDATE, W_STADKU_OD) >= 12 * 11
  AND EXTRACT(MONTH FROM W_STADKU_OD) IN (3, 4, 5, 6, 7, 8, 9);

-- zad 7

SELECT IMIE, PRZYDZIAL_MYSZY * 3 "MYSZY KWARTALNE", NVL(MYSZY_EXTRA, 0) * 3 "KWARTALNE DODATKI"
FROM KOCURY
WHERE PRZYDZIAL_MYSZY > 2 * NVL(MYSZY_EXTRA, 0)
  AND PRZYDZIAL_MYSZY >= 55;

-- zad 8

SELECT IMIE,
       CASE
           WHEN (PRZYDZIAL_MYSZY * 12 + NVL(MYSZY_EXTRA, 0) * 12) > 660
               THEN TO_CHAR(PRZYDZIAL_MYSZY * 12 + NVL(MYSZY_EXTRA, 0) * 12)
           WHEN (PRZYDZIAL_MYSZY * 12 + NVL(MYSZY_EXTRA, 0) * 12) = 660 THEN 'Limit'
           ELSE 'Ponizej 660'
           END "Zjada rocznie"
FROM KOCURY;

-- zad 9

SELECT PSEUDO,
       W_STADKU_OD "W STADKU",
       CASE
           WHEN EXTRACT(DAY FROM W_STADKU_OD) <= 15
               AND NEXT_DAY(LAST_DAY(DATE '2020-10-27') - 7, 3) >= DATE '2020-10-27'
               THEN NEXT_DAY(LAST_DAY(DATE '2020-10-27') - 7, 3)
           ELSE NEXT_DAY(LAST_DAY(ADD_MONTHS(DATE '2020-10-27', 1)) - 7, 3)
           END     "WYPLATA"
FROM KOCURY;

SELECT PSEUDO,
       W_STADKU_OD "W STADKU",
       CASE
           WHEN EXTRACT(DAY FROM W_STADKU_OD) <= 15
               AND NEXT_DAY(LAST_DAY(DATE '2020-10-29') - 7, 3) >= DATE '2020-10-29'
               THEN NEXT_DAY(LAST_DAY(DATE '2020-10-29') - 7, 3)
           ELSE NEXT_DAY(LAST_DAY(ADD_MONTHS(DATE '2020-10-29', 1)) - 7, 3)
           END     "WYPLATA"
FROM KOCURY;

-- zad 10

SELECT PSEUDO ||
       CASE
           WHEN COUNT(*) = 1 THEN ' - Unikalny'
           ELSE ' - nieunikalny'
           END "Unikalnosc atr. PSEUDO"
FROM KOCURY
GROUP BY PSEUDO;

SELECT SZEF ||
       CASE
           WHEN COUNT(*) = 1 THEN ' - Unikalny'
           ELSE ' - nieunikalny'
           END "Unikalnosc atr. SZEF"
FROM KOCURY
WHERE SZEF IS NOT NULL
GROUP BY SZEF;

-- zad 11

SELECT PSEUDO "Pseudonim", COUNT(*) "Liczba wrogow"
FROM WROGOWIE_KOCUROW
GROUP BY PSEUDO
HAVING COUNT(*) > 1;

-- zad 12

SELECT 'Liczba kotow = ' || COUNT(*) || ' lowi jako '
           || FUNKCJA || ' i zjada max. '
           || MAX(PRZYDZIAL_MYSZY + NVL(MYSZY_EXTRA, 0)) || ' myszy miesiecznie' " "
FROM KOCURY
WHERE FUNKCJA != 'SZEFUNIO'
  AND PLEC != 'M'
GROUP BY FUNKCJA
HAVING AVG(PRZYDZIAL_MYSZY + NVL(MYSZY_EXTRA, 0)) > 50;

-- zad 13

SELECT NR_BANDY, PLEC, MIN(PRZYDZIAL_MYSZY) "Minimalny przydzial"
FROM KOCURY
GROUP BY NR_BANDY, PLEC;

-- zad 14

SELECT level "Poziom", PSEUDO "Pseudonim", FUNKCJA "Funkcja", NR_BANDY "Nr bandy"
FROM KOCURY
WHERE PLEC = 'M'
CONNECT BY PRIOR PSEUDO = SZEF
START WITH FUNKCJA = 'BANDZIOR';

-- zad 15

SELECT LPAD(level - 1, 4 * (level - 1) + LENGTH(level - 1), '===>') || '      ' ||
       IMIE                         "Hierarchia",
       NVL(SZEF, 'Sam sobie panem') "Pseudo szefa",
       FUNKCJA                      "Funkcja"
FROM KOCURY
WHERE MYSZY_EXTRA IS NOT NULL
CONNECT BY PRIOR PSEUDO = SZEF
START WITH SZEF IS NULL;

-- zad 16

SELECT LPAD(PSEUDO, 4 * (LEVEL - 1) + LENGTH(PSEUDO), '    ') "Droga sluzbowa"
FROM KOCURY
CONNECT BY PRIOR SZEF = PSEUDO
START WITH (SYSDATE - W_STADKU_OD) > 11 * 365
       AND PLEC = 'M'
       AND MYSZY_EXTRA IS NULL;
