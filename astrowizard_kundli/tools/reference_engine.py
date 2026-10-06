"""Reference Vedic engine (Python + Swiss Ephemeris, SWIEPH files in assets/ephe).

Used to verify the Dart engine and to generate golden test vectors
(test/golden.json). Run with a venv that has pyswisseph installed:

    python tools/reference_engine.py test/golden.json
"""
import json
import math
import sys
from datetime import datetime, timedelta

import os
import swisseph as swe

swe.set_ephe_path(os.environ.get("SE_EPHE_PATH", os.path.join(os.path.dirname(__file__), "..", "assets", "ephe")))

FLAGS = swe.FLG_SWIEPH | swe.FLG_SIDEREAL | swe.FLG_SPEED
FLAGS_EQ = swe.FLG_SWIEPH | swe.FLG_EQUATORIAL
PLANETS = [("Sun", swe.SUN), ("Moon", swe.MOON), ("Mars", swe.MARS),
           ("Mercury", swe.MERCURY), ("Jupiter", swe.JUPITER),
           ("Venus", swe.VENUS), ("Saturn", swe.SATURN), ("Rahu", swe.MEAN_NODE)]
SEVEN = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"]
SIGNS = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio",
         "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
SIGN_LORDS = ["Mars", "Venus", "Mercury", "Moon", "Sun", "Mercury",
              "Venus", "Mars", "Jupiter", "Saturn", "Saturn", "Jupiter"]
NAK = ["Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra", "Punarvasu",
       "Pushya", "Ashlesha", "Magha", "Purva Phalguni", "Uttara Phalguni", "Hasta",
       "Chitra", "Swati", "Vishakha", "Anuradha", "Jyeshtha", "Mula", "Purva Ashadha",
       "Uttara Ashadha", "Shravana", "Dhanishta", "Shatabhisha", "Purva Bhadrapada",
       "Uttara Bhadrapada", "Revati"]
NAK_SPAN = 360.0 / 27

# ------------------------------------------------------------------ dasha
DASHA_ORDER = ["Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn", "Mercury"]
DASHA_YEARS = {"Ketu": 7, "Venus": 20, "Sun": 6, "Moon": 10, "Mars": 7, "Rahu": 18,
               "Jupiter": 16, "Saturn": 19, "Mercury": 17}
SIDM = swe.SIDM_LAHIRI
YEAR_US = 31557600 * 1000000  # 365.25 days in microseconds
EPOCH = datetime(2000, 1, 1, 12)  # JD 2451545.0


def vimshottari(moon_lon, birth):
    """Mahadashas as (lord, start, end). birth is a naive wall-clock datetime."""
    idx = int(moon_lon // NAK_SPAN)
    lord = DASHA_ORDER[idx % 9]
    frac = (moon_lon % NAK_SPAN) / NAK_SPAN
    start = birth - timedelta(microseconds=round(DASHA_YEARS[lord] * YEAR_US * frac))
    first = DASHA_ORDER.index(lord)
    out, cum = [], 0
    for i in range(9):
        l = DASHA_ORDER[(first + i) % 9]
        s = start + timedelta(microseconds=round(cum * YEAR_US))
        cum += DASHA_YEARS[l]
        e = start + timedelta(microseconds=round(cum * YEAR_US))
        out.append((l, s, e))
    return out


def children(lord, start, end):
    """Next-level sub-periods of a dasha period (same lord order rule)."""
    total_us = (end - start) // timedelta(microseconds=1)
    first = DASHA_ORDER.index(lord)
    out, cum = [], 0
    for i in range(9):
        l = DASHA_ORDER[(first + i) % 9]
        s = start + timedelta(microseconds=round(total_us * cum / 120))
        cum += DASHA_YEARS[l]
        e = end if i == 8 else start + timedelta(microseconds=round(total_us * cum / 120))
        out.append((l, s, e))
    return out


LEVELS = ["Maha", "Antar", "Pratyantar", "Sookshma", "Prana"]


def running(mahas, when, levels=5):
    res, period_list = [], mahas
    for lv in range(levels):
        hit = next((p for p in period_list if p[1] <= when < p[2]), None)
        if hit is None:
            break
        res.append(hit)
        period_list = children(*hit)
    return res


# ------------------------------------------------------------ chara dasha
# Jaimini Chara dasha, K.N. Rao method, counted from the lagna sign.
ODD_FOOTED = [0, 1, 2, 6, 7, 8]
EVEN_FOOTED = [3, 4, 5, 9, 10, 11]
NODE_EXALT = {"Rahu": 1, "Ketu": 7}  # debilitated in the opposite sign
CHARA_EXALT = {**{k: v for k, v in {"Sun": 0, "Moon": 1, "Mars": 9, "Mercury": 5,
                                    "Jupiter": 3, "Venus": 11, "Saturn": 6}.items()}, **NODE_EXALT}


def _rasi_aspects(s):
    """Jaimini sign aspects: movable->fixed, fixed->movable (not adjacent), dual->dual."""
    if s % 3 == 0:    # movable
        return [t for t in (1, 4, 7, 10) if t != (s + 1) % 12]
    if s % 3 == 1:    # fixed
        return [t for t in (0, 3, 6, 9) if t != (s - 1) % 12]
    return [t for t in (2, 5, 8, 11) if t != s]


def _stronger_co_lord(a, b, lon):
    """K.N. Rao rules for Scorpio (Mars/Ketu) and Aquarius (Saturn/Rahu)."""
    home = 7 if "Ketu" in (a, b) else 10
    sa, sb = int(lon[a] // 30), int(lon[b] // 30)
    if sa == home and sb != home:      # one lord sits in the sign itself: the other rules it
        return b
    if sb == home and sa != home:
        return a
    grahas = SEVEN + ["Rahu", "Ketu"]
    ca = sum(1 for q in grahas if q != a and int(lon[q] // 30) == sa)   # rule 1: more conjunctions
    cb = sum(1 for q in grahas if q != b and int(lon[q] // 30) == sb)
    if ca != cb:
        return a if ca > cb else b

    def support(pl, sg):               # rule 2: Jupiter, Mercury, dispositor joining/aspecting
        disp = SIGN_LORDS[sg]
        n = 0
        for q in ("Jupiter", "Mercury", disp):
            sq = int(lon[q] // 30)
            if sq == sg or sg in _rasi_aspects(sq):
                n += 1
        return n
    ra, rb = support(a, sa), support(b, sb)
    if ra != rb:
        return a if ra > rb else b
    ea, eb = CHARA_EXALT[a] == sa, CHARA_EXALT[b] == sb     # rule 3: exalted
    if ea != eb:
        return a if ea else b
    rank = lambda sg: 3 if sg % 3 == 2 else 2 if sg % 3 == 1 else 1   # rule 4: dual > fixed > movable
    if rank(sa) != rank(sb):
        return a if rank(sa) > rank(sb) else b
    return a if lon[a] % 30 > lon[b] % 30 else b          # rule 5: more advanced in sign


def chara_lord(sign, lon):
    if sign == 7:
        return _stronger_co_lord("Mars", "Ketu", lon)
    if sign == 10:
        return _stronger_co_lord("Saturn", "Rahu", lon)
    return SIGN_LORDS[sign]


def chara_years(sign, lon):
    lord = chara_lord(sign, lon)
    ls = int(lon[lord] // 30)
    n = (sign - ls) % 12 if sign in EVEN_FOOTED else (ls - sign) % 12
    years = n if n > 0 else 12
    if CHARA_EXALT[lord] == ls:
        years += 1
    elif (CHARA_EXALT[lord] + 6) % 12 == ls:
        years -= 1
    return years


def chara_order(first, forward):
    return [(first + (i if forward else -i)) % 12 for i in range(12)]


def chara_forward(lagna):
    """Sequence runs zodiacally when the 9th sign from lagna is odd-footed."""
    return (lagna + 8) % 12 in ODD_FOOTED


def chara_mahas(lon, asc, birth):
    """Two cycles (144 years): first cycle years as counted, second cycle 12 - years."""
    lagna = int(asc // 30)
    forward = chara_forward(lagna)
    order = chara_order(lagna, forward)
    out, t = [], birth
    for cycle in (0, 1):
        for sg in order:
            y = chara_years(sg, lon)
            if cycle == 1:
                y = 12 - y
            if y <= 0:
                continue
            e = t + timedelta(microseconds=y * YEAR_US // 1)
            out.append((sg, t, e))
            t = e
    return out, forward


def chara_children(sign, start, end, forward):
    total = (end - start) // timedelta(microseconds=1)
    out = []
    for i, sg in enumerate(chara_order(sign, forward)):
        s = start + timedelta(microseconds=round(total * i / 12))
        e = end if i == 11 else start + timedelta(microseconds=round(total * (i + 1) / 12))
        out.append((sg, s, e))
    return out


def chara_running(mahas, forward, when, levels=5):
    res, lst = [], mahas
    for _ in range(levels):
        hit = next((p for p in lst if p[1] <= when < p[2]), None)
        if hit is None:
            break
        res.append(hit)
        lst = chara_children(hit[0], hit[1], hit[2], forward)
    return res


# ------------------------------------------------------------------ vargas
def varga_degree(lon, n):
    """Degree (0-30) inside the divisional sign for equal-part vargas (1, 3, 9, 10, 12)."""
    size = 30.0 / n
    return (lon % 30 % size) * n


def varga_sign(lon, n):
    s = int(lon // 30)
    d = lon % 30
    odd = s % 2 == 0  # Aries, Gemini, ... are odd signs
    if n == 1:
        return s
    if n == 2:
        return 4 if (odd == (d < 15)) else 3
    if n == 3:
        return (s + 4 * int(d // 10)) % 12
    if n == 7:
        part = int(d * 7 / 30)
        return ((s if odd else (s + 6) % 12) + part) % 12
    if n == 9:
        return int(lon * 3 / 10) % 12
    if n == 10:
        part = int(d // 3)
        return ((s if odd else (s + 8) % 12) + part) % 12
    if n == 12:
        return (s + int(d / 2.5)) % 12
    if n == 30:
        if odd:
            for lim, sg in ((5, 0), (10, 10), (18, 8), (25, 2), (30, 6)):
                if d < lim:
                    return sg
        else:
            for lim, sg in ((5, 1), (12, 5), (20, 11), (25, 9), (30, 7)):
                if d < lim:
                    return sg
    raise ValueError(n)


# ------------------------------------------------------------------ panchang
TITHI = ["Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami", "Shashthi",
         "Saptami", "Ashtami", "Navami", "Dashami", "Ekadashi", "Dwadashi",
         "Trayodashi", "Chaturdashi"]
YOGA = ["Vishkambha", "Priti", "Ayushman", "Saubhagya", "Shobhana", "Atiganda",
        "Sukarma", "Dhriti", "Shoola", "Ganda", "Vriddhi", "Dhruva", "Vyaghata",
        "Harshana", "Vajra", "Siddhi", "Vyatipata", "Variyana", "Parigha", "Shiva",
        "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma", "Indra", "Vaidhriti"]
KARANA7 = ["Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija", "Vishti"]
VARA = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
VARA_LORD = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"]
CHALDEAN = ["Sun", "Venus", "Mercury", "Moon", "Saturn", "Jupiter", "Mars"]


def sun_times(year, month, day, lat, lon, tz):
    """NOAA sunrise/sunset equations. Returns local clock hours (sr, ss) or None."""
    jd = swe.julday(year, month, day, 12.0 - tz)
    t = (jd - 2451545.0) / 36525.0
    rad = math.radians
    l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360
    m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
    e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
    c = (math.sin(rad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t))
         + math.sin(rad(2 * m)) * (0.019993 - 0.000101 * t)
         + math.sin(rad(3 * m)) * 0.000289)
    true_long = l0 + c
    omega = 125.04 - 1934.136 * t
    lam = true_long - 0.00569 - 0.00478 * math.sin(rad(omega))
    eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
    eps = eps0 + 0.00256 * math.cos(rad(omega))
    decl = math.asin(math.sin(rad(eps)) * math.sin(rad(lam)))
    y = math.tan(rad(eps) / 2) ** 2
    eq = 4 * math.degrees(
        y * math.sin(2 * rad(l0)) - 2 * e * math.sin(rad(m))
        + 4 * e * y * math.sin(rad(m)) * math.cos(2 * rad(l0))
        - 0.5 * y * y * math.sin(4 * rad(l0)) - 1.25 * e * e * math.sin(2 * rad(m)))
    cos_ha = (math.cos(rad(90.833)) / (math.cos(rad(lat)) * math.cos(decl))
              - math.tan(rad(lat)) * math.tan(decl))
    if cos_ha < -1 or cos_ha > 1:
        return None
    ha = math.degrees(math.acos(cos_ha))
    sr = (720 - 4 * (lon + ha) - eq) / 60 + tz
    ss = (720 - 4 * (lon - ha) - eq) / 60 + tz
    return sr, ss


def vedic_vara(wall, lat, lon, tz):
    """Weekday index (Sunday=0) of the Vedic day (starts at sunrise)."""
    st = sun_times(wall.year, wall.month, wall.day, lat, lon, tz)
    hours = wall.hour + wall.minute / 60 + wall.second / 3600
    wd = (wall.weekday() + 1) % 7
    if st is not None and hours < st[0]:
        wd = (wd + 6) % 7
    return wd


def panchang(sun, moon, wall, lat, lon, tz):
    diff = (moon - sun) % 360
    tn = int(diff // 12) + 1
    k = int(diff // 6)
    if k == 0:
        kar = "Kimstughna"
    elif k >= 57:
        kar = ["Shakuni", "Chatushpada", "Naga"][k - 57]
    else:
        kar = KARANA7[(k - 1) % 7]
    p = ((tn - 1) % 15) + 1
    tname = TITHI[p - 1] if p < 15 else ("Purnima" if tn == 15 else "Amavasya")
    st = sun_times(wall.year, wall.month, wall.day, lat, lon, tz)
    return {
        "tithiNumber": tn, "tithi": tname,
        "paksha": "Shukla" if tn <= 15 else "Krishna",
        "nakshatra": NAK[int(moon // NAK_SPAN)],
        "yoga": YOGA[int(((sun + moon) % 360) // NAK_SPAN)],
        "karana": kar,
        "vara": VARA[vedic_vara(wall, lat, lon, tz)],
        "sunrise": st[0] if st else None, "sunset": st[1] if st else None,
    }


# ------------------------------------------------------------------ ashtakavarga
# contributor -> houses (counted from the contributor) that receive a bindu
AV = {
    "Sun": {"Sun": [1, 2, 4, 7, 8, 9, 10, 11], "Moon": [3, 6, 10, 11],
            "Mars": [1, 2, 4, 7, 8, 9, 10, 11], "Mercury": [3, 5, 6, 9, 10, 11, 12],
            "Jupiter": [5, 6, 9, 11], "Venus": [6, 7, 12],
            "Saturn": [1, 2, 4, 7, 8, 9, 10, 11], "Lagna": [3, 4, 6, 10, 11, 12]},
    "Moon": {"Sun": [3, 6, 7, 8, 10, 11], "Moon": [1, 3, 6, 7, 10, 11],
             "Mars": [2, 3, 5, 6, 9, 10, 11], "Mercury": [1, 3, 4, 5, 7, 8, 10, 11],
             "Jupiter": [1, 4, 7, 8, 10, 11, 12], "Venus": [3, 4, 5, 7, 9, 10, 11],
             "Saturn": [3, 5, 6, 11], "Lagna": [3, 6, 10, 11]},
    "Mars": {"Sun": [3, 5, 6, 10, 11], "Moon": [3, 6, 11],
             "Mars": [1, 2, 4, 7, 8, 10, 11], "Mercury": [3, 5, 6, 11],
             "Jupiter": [6, 10, 11, 12], "Venus": [6, 8, 11, 12],
             "Saturn": [1, 4, 7, 8, 9, 10, 11], "Lagna": [1, 3, 6, 10, 11]},
    "Mercury": {"Sun": [5, 6, 9, 11, 12], "Moon": [2, 4, 6, 8, 10, 11],
                "Mars": [1, 2, 4, 7, 8, 9, 10, 11], "Mercury": [1, 3, 5, 6, 9, 10, 11, 12],
                "Jupiter": [6, 8, 11, 12], "Venus": [1, 2, 3, 4, 5, 8, 9, 11],
                "Saturn": [1, 2, 4, 7, 8, 9, 10, 11], "Lagna": [1, 2, 4, 6, 8, 10, 11]},
    "Jupiter": {"Sun": [1, 2, 3, 4, 7, 8, 9, 10, 11], "Moon": [2, 5, 7, 9, 11],
                "Mars": [1, 2, 4, 7, 8, 10, 11], "Mercury": [1, 2, 4, 5, 6, 9, 10, 11],
                "Jupiter": [1, 2, 3, 4, 7, 8, 10, 11], "Venus": [2, 5, 6, 9, 10, 11],
                "Saturn": [3, 5, 6, 12], "Lagna": [1, 2, 4, 5, 6, 7, 9, 10, 11]},
    "Venus": {"Sun": [8, 11, 12], "Moon": [1, 2, 3, 4, 5, 8, 9, 11, 12],
              "Mars": [3, 5, 6, 9, 11, 12], "Mercury": [3, 5, 6, 9, 11],
              "Jupiter": [5, 8, 9, 10, 11], "Venus": [1, 2, 3, 4, 5, 8, 9, 10, 11],
              "Saturn": [3, 4, 5, 8, 9, 10, 11], "Lagna": [1, 2, 3, 4, 5, 8, 9, 11]},
    "Saturn": {"Sun": [1, 2, 4, 7, 8, 10, 11], "Moon": [3, 6, 11],
               "Mars": [3, 5, 6, 10, 11, 12], "Mercury": [6, 8, 9, 10, 11, 12],
               "Jupiter": [5, 6, 11, 12], "Venus": [6, 11, 12],
               "Saturn": [3, 5, 6, 11], "Lagna": [1, 3, 4, 6, 10, 11]},
}
AV_TOTALS = {"Sun": 48, "Moon": 49, "Mars": 39, "Mercury": 54,
             "Jupiter": 56, "Venus": 52, "Saturn": 39}


def ashtakavarga(rasi_signs, lagna_sign):
    pos = dict(rasi_signs)
    pos["Lagna"] = lagna_sign
    bav = {}
    for target, contrib in AV.items():
        row = [0] * 12
        for who, houses in contrib.items():
            for h in houses:
                row[(pos[who] + h - 1) % 12] += 1
        bav[target] = row
    sav = [sum(bav[p][i] for p in AV) for i in range(12)]
    return bav, sav


# ------------------------------------------------------------------ shadbala
NAT = {  # natural relationship: 1 friend, 0 neutral, -1 enemy
    "Sun": {"Moon": 1, "Mars": 1, "Mercury": 0, "Jupiter": 1, "Venus": -1, "Saturn": -1},
    "Moon": {"Sun": 1, "Mars": 0, "Mercury": 1, "Jupiter": 0, "Venus": 0, "Saturn": 0},
    "Mars": {"Sun": 1, "Moon": 1, "Mercury": -1, "Jupiter": 1, "Venus": 0, "Saturn": 0},
    "Mercury": {"Sun": 1, "Moon": -1, "Mars": 0, "Jupiter": 0, "Venus": 1, "Saturn": 0},
    "Jupiter": {"Sun": 1, "Moon": 1, "Mars": 1, "Mercury": -1, "Venus": -1, "Saturn": 0},
    "Venus": {"Sun": -1, "Moon": -1, "Mars": 0, "Mercury": 1, "Jupiter": 0, "Saturn": 1},
    "Saturn": {"Sun": -1, "Moon": -1, "Mars": -1, "Mercury": 1, "Jupiter": 0, "Venus": 1},
}
DEBIL = {"Sun": 190.0, "Moon": 213.0, "Mars": 118.0, "Mercury": 345.0,
         "Jupiter": 275.0, "Venus": 177.0, "Saturn": 20.0}
MOOLA = {"Sun": (4, 0, 20), "Moon": (1, 3, 30), "Mars": (0, 0, 12), "Mercury": (5, 16, 20),
         "Jupiter": (8, 0, 10), "Venus": (6, 0, 15), "Saturn": (10, 0, 20)}
NAISARGIKA = {"Sun": 60.0, "Moon": 51.43, "Venus": 42.85, "Jupiter": 34.28,
              "Mercury": 25.71, "Mars": 17.14, "Saturn": 8.57}
REQUIRED = {"Sun": 390, "Moon": 360, "Mars": 300, "Mercury": 420,
            "Jupiter": 390, "Venus": 330, "Saturn": 300}
MEAN_L = {"Mercury": (252.25084, 149472.67411175), "Venus": (181.97973, 58517.81538729),
          "Earth": (100.46435, 35999.37244981), "Mars": (-4.55343205, 19140.30268499),
          "Jupiter": (34.39644051, 3034.74612775), "Saturn": (49.95424423, 1222.49362201)}


def wrap180(x):
    return (x + 180) % 360 - 180


def ang_diff(a, b):
    return abs(wrap180(a - b))


def vara_points(planet, vsign, d1_sign, lon_in_d1=None, varga=None):
    """Saptavargaja dignity points of `planet` standing in `vsign` of some varga."""
    if varga == 1 and lon_in_d1 is not None:
        sg, a, b = MOOLA[planet]
        if int(lon_in_d1 // 30) == sg:  # sign-level moolatrikona (VP Jain / BV Raman)
            return 45.0
    lord = SIGN_LORDS[vsign]
    if lord == planet:
        return 30.0
    nat = NAT[planet][lord]
    house = (d1_sign[lord] - d1_sign[planet]) % 12 + 1
    temp = 1 if house in (2, 3, 4, 10, 11, 12) else -1
    return {2: 22.5, 1: 15.0, 0: 7.5, -1: 3.75, -2: 1.875}[nat + temp]


def drishti(d, planet=None):
    """Sphuta drishti (virupas) of `planet` on a point d degrees ahead of it
    (BV Raman / BPHS table; Mars, Jupiter, Saturn special aspects are *added*)."""
    d %= 360
    if d < 30 or d >= 300:
        return 0.0
    if d < 60:
        return (d - 30) / 2
    if d < 90:
        return (d - 45) + (45.0 if planet == "Saturn" else 0.0)
    if d < 120:
        return 30 + (120 - d) / 2 + (15.0 if planet == "Mars" else 0.0)
    if d < 150:
        return (150 - d) + (30.0 if planet == "Jupiter" else 0.0)
    if d < 180:
        return (d - 150) * 2
    v = (300 - d) / 2
    if planet == "Mars" and 210 <= d < 240:
        v += 15
    if planet == "Jupiter" and 240 <= d < 270:
        v += 30
    if planet == "Saturn" and 270 <= d < 300:
        v += 45
    return v


def jd_to_wall(jd, tz):
    return EPOCH + timedelta(days=jd - 2451545.0) + timedelta(hours=tz)


def sun_sid(jd):
    return swe.calc_ut(jd, swe.SUN, FLAGS)[0][0]


def ingress_jd(jd, target):
    """Last instant before jd at which the sidereal Sun was at `target` degrees."""
    past = (sun_sid(jd) - target) % 360
    lo = jd - past / 0.95 - 1
    hi = min(jd, jd - past / 1.02 + 1)
    for _ in range(50):
        mid = (lo + hi) / 2
        if wrap180(sun_sid(mid) - target) < 0:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


WEEK_LORDS = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"]


def jdn(y, m, d):
    a = (14 - m) // 12
    y2 = y + 4800 - a
    m2 = m + 12 * a - 3
    return d + (153 * m2 + 2) // 5 + 365 * y2 + y2 // 4 - y2 // 100 + y2 // 400 - 32045


def shadbala(inp):
    """inp: dict with lon, speed, decl (per planet), asc, mc, ayanamsa, jd, tz, lat,
    lon_geo, wall (datetime), sun_ingress_jd, mesha_jd."""
    lon, decl = inp["lon"], inp["decl"]
    asc, mc = inp["asc"], inp["mc"]
    tz, wall = inp["tz"], inp["wall"]
    lagna = int(asc // 30)
    d1 = {p: int(lon[p] // 30) for p in SEVEN}
    out = {}

    # --- shared timing data
    hours = wall.hour + wall.minute / 60 + wall.second / 3600
    sr, ss = sun_times(wall.year, wall.month, wall.day, inp["lat"], inp["lon_geo"], tz)
    vara = vedic_vara(wall, inp["lat"], inp["lon_geo"], tz)
    vara_lord = VARA_LORD[vara]
    elong = (lon["Moon"] - lon["Sun"]) % 360
    elong180 = elong if elong <= 180 else 360 - elong
    noon = (sr + ss) / 2
    dm = abs(hours - noon)
    if dm > 12:
        dm = 24 - dm
    # tribhaga
    if sr <= hours < ss:
        part = int((hours - sr) / ((ss - sr) / 3))
        tri_lord = ["Mercury", "Sun", "Saturn"][min(part, 2)]
    else:
        if hours >= ss:
            start, end = ss, sr + 24
            h = hours
        else:
            start, end = ss - 24, sr
            h = hours
        part = int((h - start) / ((end - start) / 3))
        tri_lord = ["Moon", "Venus", "Mars"][min(part, 2)]
    # hora
    hh = hours if hours >= sr else hours + 24
    n = int(hh - sr)
    hora_lord = CHALDEAN[(CHALDEAN.index(vara_lord) + n) % 7]
    # abda / masa lords: classical ahargana method (Kali epoch, 360-day year, 30-day month)
    vday = wall.date() if hours >= sr else (wall - timedelta(days=1)).date()
    ahar = jdn(vday.year, vday.month, vday.day) - 588465  # epoch day = 1
    abda_lord = WEEK_LORDS[(360 * (ahar // 360) + 4) % 7]
    masa_lord = WEEK_LORDS[(30 * (ahar // 30) + 4) % 7]

    t_cent = (inp["jd"] - 2451545.0) / 36525.0
    sun_mean = (MEAN_L["Earth"][0] + MEAN_L["Earth"][1] * t_cent + 180) % 360

    def hel(p):
        return (MEAN_L[p][0] + MEAN_L[p][1] * t_cent) % 360

    # drik prerequisites
    waxing = elong < 180
    benefic = {"Jupiter": True, "Venus": True, "Moon": waxing,
               "Sun": False, "Mars": False, "Saturn": False}
    # Mercury: benefic when alone or with more benefics, malefic with more malefics,
    # tie -> the nearest companion decides
    comp = [q for q in SEVEN + ["Rahu", "Ketu"] if q != "Mercury"
            and int(lon[q] // 30) == int(lon["Mercury"] // 30)]
    nb_ = sum(1 for q in comp if benefic.get(q, False))
    nm_ = len(comp) - nb_
    if not comp or nb_ > nm_:
        benefic["Mercury"] = True
    elif nm_ > nb_:
        benefic["Mercury"] = False
    else:
        near = min(comp, key=lambda q: abs(lon[q] - lon["Mercury"]))
        benefic["Mercury"] = benefic.get(near, False)

    for p in SEVEN:
        # ---- sthana
        uc = ang_diff(lon[p], DEBIL[p]) / 3
        sv = 0.0
        for v in (1, 2, 3, 7, 9, 12, 30):
            vs = varga_sign(lon[p], v)
            sv += vara_points(p, vs, d1, lon[p] if v == 1 else None, v)
        rs, ns = d1[p], varga_sign(lon[p], 9)
        want_even = p in ("Moon", "Venus")
        oj = 0.0
        for sg in (rs, ns):
            if (sg % 2 == 1) == want_even:
                oj += 15.0
        house = (d1[p] - lagna) % 12 + 1
        ke = 60.0 if house in (1, 4, 7, 10) else (30.0 if house in (2, 5, 8, 11) else 15.0)
        dg = lon[p] % 30
        dr = 0.0
        if (p in ("Sun", "Jupiter", "Mars") and dg < 10) or \
           (p in ("Mercury", "Saturn") and 10 <= dg < 20) or \
           (p in ("Moon", "Venus") and dg >= 20):
            dr = 15.0
        sthana = uc + sv + oj + ke + dr
        # ---- dig
        strong = {"Jupiter": asc, "Mercury": asc, "Sun": mc, "Mars": mc,
                  "Saturn": (asc + 180) % 360, "Moon": (mc + 180) % 360,
                  "Venus": (mc + 180) % 360}[p]
        dig = ang_diff(lon[p], (strong + 180) % 360) / 3
        # ---- kala
        if p == "Mercury":
            nato = 60.0
        elif p in ("Moon", "Mars", "Saturn"):
            nato = dm / 12 * 60
        else:
            nato = 60 - dm / 12 * 60
        pak_plain = elong180 / 3 if benefic[p] else 60 - elong180 / 3
        pak = pak_plain * 2 if p == "Moon" else pak_plain
        tri = 60.0 if (p == "Jupiter" or p == tri_lord) else 0.0
        abda = 15.0 if p == abda_lord else 0.0
        masa = 30.0 if p == masa_lord else 0.0
        vr = 45.0 if p == vara_lord else 0.0
        hr = 60.0 if p == hora_lord else 0.0
        # declination from sayana longitude only (ecliptic latitude ignored), as in the books
        d_ = math.degrees(math.asin(math.sin(math.radians(23.45)) *
             math.sin(math.radians((lon[p] + inp["ayanamsa"]) % 360))))
        if p in ("Moon", "Saturn", "Mercury"):
            ay_plain = (23.45 - d_) / 46.9 * 60
        else:
            ay_plain = (23.45 + d_) / 46.9 * 60
        ay_plain = max(0.0, min(60.0, ay_plain))
        ay = ay_plain * 2 if p == "Sun" else ay_plain
        kala = nato + pak + tri + abda + masa + vr + hr + ay
        # ---- cheshta
        if p in ("Sun", "Moon"):
            ch = 0.0  # books (VP Jain, BV Raman) give Sun/Moon no Cheshta bala
        else:
            sph = (lon[p] + inp["ayanamsa"]) % 360
            if p in ("Mars", "Jupiter", "Saturn"):
                seeghra, madhya = sun_mean, hel(p)
            else:
                seeghra, madhya = hel(p), sun_mean
            avg = madhya + wrap180(sph - madhya) / 2
            ch = ang_diff(seeghra, avg) / 3
        # ---- drik
        acc = 0.0
        for q in SEVEN:
            if q == p:
                continue
            d = (lon[p] - lon[q]) % 360
            v = drishti(d, q)
            acc += v if benefic[q] else -v
        drik = acc / 4
        total = sthana + dig + kala + ch + NAISARGIKA[p] + drik
        out[p] = {"uccha": uc, "saptavargaja": sv, "ojhayugma": oj, "kendradi": ke,
                  "drekkana": dr, "sthana": sthana, "dig": dig, "kala": kala,
                  "nathonnata": nato, "paksha": pak, "tribhaga": tri, "abda": abda,
                  "masa": masa, "vara": vr, "hora": hr, "ayana": ay,
                  "cheshta": ch, "naisargika": NAISARGIKA[p], "drik": drik,
                  "total": total, "rupas": total / 60, "required": REQUIRED[p],
                  "ratio": total / REQUIRED[p]}
    out["_meta"] = {"abdaLord": abda_lord, "masaLord": masa_lord, "horaLord": hora_lord,
                    "triLord": tri_lord, "varaLord": vara_lord,
                    "benefic": benefic}
    return out


def relations(d1):
    """Natural (BPHS), temporal (tatkalika) and compound (panchadha) maitri.
    d1: planet -> rasi index. Temporal friend = planet placed in 2/3/4/10/11/12
    from the other; enemy otherwise. Compound = natural + temporal (-2..+2)."""
    out = {}
    for p in SEVEN:
        for q in SEVEN:
            if p == q:
                continue
            nat = NAT[p][q]
            house = (d1[q] - d1[p]) % 12 + 1
            tem = 1 if house in (2, 3, 4, 10, 11, 12) else -1
            out["%s>%s" % (p, q)] = {"natural": nat, "temporal": tem, "compound": nat + tem}
    return out


MIN_BHAVA_BALA = 420.0  # 7 rupas


def sign_class(sign, deg):
    if sign in (2, 5, 6, 10) or (sign == 8 and deg < 15):
        return "nara"
    if sign in (3, 11) or (sign == 9 and deg >= 15):
        return "jalachara"
    if sign == 7:
        return "keeta"
    return "chatushpada"


def bhava_bala(lon, asc, mc, totals, benefic):
    """Bhava bala per house (equal-house madhya = lagna degree in each sign):
    adhipati (lord's Shadbala) + bhava dig + bhava drishti."""
    rows = []
    for h in range(1, 13):
        mid = (asc + 30 * (h - 1)) % 360
        sign = int(mid // 30)
        lord = SIGN_LORDS[sign]
        cls = sign_class(sign, mid % 30)
        strong = {"nara": asc, "jalachara": (mc + 180) % 360, "chatushpada": mc,
                  "keeta": (asc + 180) % 360}[cls]
        dig = ang_diff(mid, (strong + 180) % 360) / 3
        acc = 0.0
        for q in SEVEN:
            v = drishti((mid - lon[q]) % 360, q)
            acc += v if benefic[q] else -v
        drik = acc / 4
        adhi = totals[lord]
        total = adhi + dig + drik
        rows.append({"house": h, "sign": sign, "lord": lord, "class": cls, "adhipati": adhi,
                     "dig": dig, "drishti": drik, "total": total, "rupas": total / 60,
                     "ratio": total / MIN_BHAVA_BALA})
    return rows


# ------------------------------------------------------------ planet insight
EXALT_SIGN = {"Sun": 0, "Moon": 1, "Mars": 9, "Mercury": 5, "Jupiter": 3, "Venus": 11, "Saturn": 6}
OWN_SIGNS = {"Sun": [4], "Moon": [3], "Mars": [0, 7], "Mercury": [2, 5],
             "Jupiter": [8, 11], "Venus": [1, 6], "Saturn": [9, 10]}
COMBUST_DEG = {"Moon": 12, "Mars": 17, "Mercury": 14, "Jupiter": 11, "Venus": 10, "Saturn": 15}
ASPECT_OFFSETS = {"Mars": (4, 7, 8), "Jupiter": (5, 7, 9), "Saturn": (3, 7, 10),
                  "Rahu": (5, 7, 9), "Ketu": (5, 7, 9)}
BALADI = ["Bala", "Kumara", "Yuva", "Vriddha", "Mrita"]
CHARA_KARAKAS7 = ["Atmakaraka", "Amatyakaraka", "Bhratrikaraka", "Matrikaraka",
                  "Pitrikaraka", "Putrakaraka", "Darakaraka"]
CHARA_KARAKAS8 = ["Atmakaraka", "Amatyakaraka", "Bhratrikaraka", "Matrikaraka",
                  "Pitrikaraka", "Putrakaraka", "Gnatikaraka", "Darakaraka"]


def aspect_offsets(planet):
    """Houses counted from the planet's own house that it aspects (7th for all)."""
    return ASPECT_OFFSETS.get(planet, (7,))


def dignity(p, sign, compound):
    """Returns (name, points) of planet p standing in `sign`."""
    if EXALT_SIGN[p] == sign:
        return "Exalted", 20
    if (EXALT_SIGN[p] + 6) % 12 == sign:
        return "Debilitated", 0
    if sign in OWN_SIGNS[p]:
        return "Own sign", 17
    c = compound[p][SIGN_LORDS[sign]]
    return {2: ("Adhi-mitra sign", 15), 1: ("Friend's sign", 12), 0: ("Neutral sign", 8),
            -1: ("Enemy's sign", 4), -2: ("Adhi-shatru sign", 2)}[c]


def chara_karakas(lon, include_rahu):
    cand = [(lon[p] % 30, p) for p in ("Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn")]
    if include_rahu:
        cand.append((30 - lon["Rahu"] % 30, "Rahu"))
    cand.sort(key=lambda x: -x[0])
    names = CHARA_KARAKAS8 if include_rahu else CHARA_KARAKAS7
    return {p: names[i] for i, (_, p) in enumerate(cand)}


def planet_insight(lon, speed, asc, sb, bav):
    """Per-planet details: to/from aspects, avasthas, chara karaka, dominance."""
    lagna = int(asc // 30)
    names = SEVEN + ["Rahu", "Ketu"]
    sign = {p: int(lon[p] // 30) for p in names}
    house = {p: (sign[p] - lagna) % 12 + 1 for p in names}
    rasi = {p: sign[p] for p in SEVEN}
    rel = relations(rasi)
    compound = {p: {q: rel["%s>%s" % (p, q)]["compound"] for q in SEVEN if q != p} for p in SEVEN}
    k7 = chara_karakas(lon, False)
    k8 = chara_karakas(lon, True)
    ratio = {p: sb[p]["ratio"] for p in SEVEN}
    out = {}
    for p in names:
        h = house[p]
        # aspects FROM p (sign based): houses counted from p's house
        frm = []
        for off in aspect_offsets(p):
            th = (h + off - 2) % 12 + 1
            frm.append({"offset": off, "house": th,
                        "planets": [q for q in names if q != p and house[q] == th]})
        # aspects TO p: planets whose aspect lands on p's house
        to = []
        for q in names:
            if q == p:
                continue
            for off in aspect_offsets(q):
                if (house[q] + off - 2) % 12 + 1 == h:
                    v = drishti((lon[p] - lon[q]) % 360, q) if q in SEVEN and p in SEVEN else None
                    to.append({"planet": q, "offset": off, "virupa": v})
        info = {"house": h, "sign": sign[p],
                "conjunct": [q for q in names if q != p and house[q] == h],
                "aspectsFrom": frm, "aspectsTo": to,
                "retrograde": speed[p] < 0 if p in speed else False,
                "karaka7": k7.get(p), "karaka8": k8.get(p)}
        if p in SEVEN:
            info["lordOf"] = sorted((sg - lagna) % 12 + 1 for sg in OWN_SIGNS[p])
            d = lon[p] % 30
            idx = min(int(d // 6), 4)
            info["baladi"] = BALADI[idx if sign[p] % 2 == 0 else 4 - idx]
            dname, dpts = dignity(p, sign[p], compound)
            info["dignity"] = dname
            sep = abs((lon[p] - lon["Sun"] + 180) % 360 - 180)
            limit = COMBUST_DEG.get(p)
            if p == "Mercury" and speed[p] < 0:
                limit = 12
            if p == "Venus" and speed[p] < 0:
                limit = 8
            combust = limit is not None and sep < limit
            info["combust"] = combust
            info["vargottama"] = varga_sign(lon[p], 9) == sign[p]
            info["jagradadi"] = ("Jagrat" if dname in ("Exalted", "Own sign") else
                                 "Sushupti" if dname in ("Debilitated", "Enemy's sign", "Adhi-shatru sign")
                                 else "Swapna")
            if combust:
                dd = "Kopita"
            elif dname == "Exalted":
                dd = "Deepta"
            elif dname == "Own sign":
                dd = "Swastha"
            elif dname == "Debilitated":
                dd = "Khala"
            else:
                dd = {"Adhi-mitra sign": "Mudita", "Friend's sign": "Shanta", "Neutral sign": "Dina",
                      "Enemy's sign": "Dukhita", "Adhi-shatru sign": "Vikala"}[dname]
            info["deeptadi"] = dd
            sh = min(ratio[p], 1.5) / 1.5 * 40
            av = bav[p][sign[p]] / 8 * 20
            asp = 20 * min(max((sb[p]["drik"] + 30) / 60, 0.0), 1.0)
            info["dominance"] = {"shadbala": sh, "ashtakavarga": av, "dignity": dpts, "aspects": asp,
                                 "total": sh + av + dpts + asp, "bindus": bav[p][sign[p]]}
        out[p] = info
    ranked = sorted(SEVEN, key=lambda q: -out[q]["dominance"]["total"])
    for i, q in enumerate(ranked):
        out[q]["dominance"]["rank"] = i + 1
    return out


# ------------------------------------------------------------------ driver
def compute_all(wall, tz, lat, lon_geo, when):
    ut = wall - timedelta(hours=tz)
    jd = swe.julday(ut.year, ut.month, ut.day, ut.hour + ut.minute / 60 + ut.second / 3600)
    swe.set_sid_mode(SIDM)
    lon, speed, decl = {}, {}, {}
    for name, pid in PLANETS:
        pos, _ = swe.calc_ut(jd, pid, FLAGS)
        lon[name], speed[name] = pos[0], pos[3]
    lon["Ketu"] = (lon["Rahu"] + 180) % 360
    for name, pid in PLANETS[:7]:
        decl[name] = swe.calc_ut(jd, pid, FLAGS_EQ)[0][1]
    cusps, ascmc = swe.houses_ex(jd, lat, lon_geo, b"E", swe.FLG_SIDEREAL)
    asc, mc = ascmc[0], ascmc[1]
    ayan = swe.get_ayanamsa_ut(jd)
    lagna = int(asc // 30)

    vargas = {}
    for n in (1, 3, 9, 10):
        vargas["D%d" % n] = {"lagna": varga_sign(asc, n),
                             "lagnaDeg": varga_degree(asc, n),
                             "planets": {p: varga_sign(lon[p], n) for p in lon},
                             "deg": {p: varga_degree(lon[p], n) for p in lon}}
    rasi = {p: int(lon[p] // 30) for p in SEVEN}
    bav, sav = ashtakavarga(rasi, lagna)
    assert sum(sav) == 337, sum(sav)
    for p, tot in AV_TOTALS.items():
        assert sum(bav[p]) == tot, (p, sum(bav[p]))

    sb_inp = {"lon": lon, "speed": speed, "decl": decl, "asc": asc, "mc": mc,
              "ayanamsa": ayan, "jd": jd, "tz": tz, "lat": lat, "lon_geo": lon_geo,
              "wall": wall}
    sb = shadbala(sb_inp)
    mahas = vimshottari(lon["Moon"], wall)
    run = running(mahas, when, 5)
    return {
        "input": {"wall": wall.isoformat(), "tz": tz, "lat": lat, "lon": lon_geo,
                  "when": when.isoformat()},
        "jd": jd, "asc": asc, "mc": mc, "ayanamsa": ayan,
        "planets": lon, "speed": speed, "decl": decl,
        "vargas": vargas,
        "panchang": panchang(lon["Sun"], lon["Moon"], wall, lat, lon_geo, tz),
        "ashtakavarga": {"bav": bav, "sav": sav},
        "shadbala": sb,
        "relations": relations(rasi),
        "insight": planet_insight(lon, speed, asc, sb, bav),
        "bhavaBala": bhava_bala(lon, asc, mc, {p: sb[p]["total"] for p in SEVEN}, sb["_meta"]["benefic"]),
        "dasha": [(l, a.isoformat(), b.isoformat()) for l, a, b in mahas],
        "chara": {"forward": chara_forward(lagna),
                  "years": {str(sg): chara_years(sg, lon) for sg in range(12)},
                  "mahas": [(sg, a.isoformat(), b.isoformat()) for sg, a, b in chara_mahas(lon, asc, wall)[0]],
                  "running": [(sg, a.isoformat(), b.isoformat()) for sg, a, b in
                              chara_running(chara_mahas(lon, asc, wall)[0], chara_forward(lagna), when)]},
        "runningDasha": [(l, a.isoformat(), b.isoformat()) for l, a, b in run],
    }


def describe(lon):
    s = int(lon // 30)
    n = int(lon // NAK_SPAN)
    pada = int((lon % NAK_SPAN) // (NAK_SPAN / 4)) + 1
    return SIGNS[s], lon % 30, NAK[n], pada


CASES = {
    "modi_1950": (datetime(1950, 9, 17, 11, 0, 0), 5.5, 23.78, 72.63,
                  datetime(2026, 10, 6, 12, 0, 0)),
    "agra_2001_secs": (datetime(2001, 3, 14, 5, 27, 41), 5.5, 27.1767, 78.0081,
                       datetime(2026, 10, 6, 12, 0, 0)),
    "vpjain_1981": (datetime(1981, 9, 13, 1, 30, 0), 5.5, 28 + 39 / 60, 77 + 13 / 60,
                    datetime(2026, 10, 6, 12, 0, 0)),
    "j2000_greenwich": (datetime(2000, 1, 1, 12, 0, 0), 0.0, 51.4769, 0.0,
                        datetime(2026, 10, 6, 12, 0, 0)),
}

if __name__ == "__main__":
    golden = {k: compute_all(*v) for k, v in CASES.items()}
    with open(sys.argv[1] if len(sys.argv) > 1 else "golden.json", "w") as f:
        json.dump(golden, f, indent=1, default=str)
    for k, g in golden.items():
        print("==", k, "asc", round(g["asc"], 3), "ayanamsa", round(g["ayanamsa"], 4))
        print(" panchang", g["panchang"])
        print(" D9 lagna", SIGNS[g["vargas"]["D9"]["lagna"]], "D10 lagna", SIGNS[g["vargas"]["D10"]["lagna"]])
        print(" SAV", g["ashtakavarga"]["sav"])
        for p in SEVEN:
            s = g["shadbala"][p]
            print("  %-8s sthana %6.1f dig %5.1f kala %6.1f chesta %5.1f naisarg %5.1f drik %6.1f"
                  " = %6.1f (%.2f rupa, %.2fx req)" % (p, s["sthana"], s["dig"], s["kala"],
                  s["cheshta"], s["naisargika"], s["drik"], s["total"], s["rupas"], s["ratio"]))
        print(" meta", g["shadbala"]["_meta"])
        for lv, (l, a, b) in zip(LEVELS, g["runningDasha"]):
            print("  %-10s %-8s %s -> %s" % (lv, l, a, b))
