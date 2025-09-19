# Configuration par défaut pour nerd-dictation avec ponctuation française
# Ce fichier est automatiquement installé dans ~/.config/nerd-dictation/nerd-dictation.py

def nerd_dictation_process(text):
    """
    Fonction de remplacement pour améliorer la ponctuation française
    et les expressions courantes.
    """
    
    # Milliers et centaines (les plus longs d'abord)
    text = text.replace("douze mille", "12000")
    text = text.replace("dix mille", "10000")
    text = text.replace("neuf mille", "9000") 
    text = text.replace("huit mille", "8000")
    text = text.replace("sept mille", "7000")
    text = text.replace("six mille", "6000")
    text = text.replace("cinq mille", "5000")
    text = text.replace("quatre mille", "4000")
    text = text.replace("trois mille", "3000")
    text = text.replace("deux mille", "2000")
    text = text.replace("mille", "1000")
    
    # Centaines complètes
    text = text.replace("six cent quatre-vingt-quinze", "695")
    text = text.replace("quatre cent vingt", "420")
    text = text.replace("neuf cent", "900")
    text = text.replace("huit cent", "800")
    text = text.replace("sept cent", "700") 
    text = text.replace("six cent", "600")
    text = text.replace("cinq cent", "500")
    text = text.replace("quatre cent", "400")
    text = text.replace("trois cent", "300")
    text = text.replace("deux cent", "200")
    text = text.replace("cent", "100")
    
    # Nombres composés
    text = text.replace("quatre-vingt-quinze", "95")
    text = text.replace("quatre-vingt-dix", "90")
    text = text.replace("quatre-vingts", "80")
    text = text.replace("soixante-quinze", "75")
    text = text.replace("soixante-dix", "70")
    text = text.replace("cinquante-cinq", "55")
    text = text.replace("quarante-deux", "42")
    text = text.replace("trente-trois", "33")
    text = text.replace("vingt-et-un", "21")
    
    text = text.replace("cinquante", "50")
    text = text.replace("quarante", "40")
    text = text.replace("trente", "30")
    text = text.replace("vingt", "20")
    text = text.replace("dix-neuf", "19")
    text = text.replace("dix-huit", "18")
    text = text.replace("dix-sept", "17")
    text = text.replace("seize", "16")
    text = text.replace("quinze", "15")
    text = text.replace("quatorze", "14")
    text = text.replace("treize", "13")
    text = text.replace("douze", "12")
    text = text.replace("onze", "11")
    text = text.replace("dix", "10")
    text = text.replace("neuf", "9")
    text = text.replace("huit", "8")
    text = text.replace("sept", "7")
    text = text.replace("six", "6")
    text = text.replace("cinq", "5")
    text = text.replace("quatre", "4")
    text = text.replace("trois", "3")
    text = text.replace("deux", "2")
    text = text.replace("un", "1")
    text = text.replace("zéro", "0")
    
    # Ponctuation de base avec variantes
    text = text.replace(" virgule", ",")
    
    # Variantes pour point d'interrogation
    text = text.replace(" point d'interrogation", " ?")
    text = text.replace(" point interrogation", " ?")
    text = text.replace(" interrogation", " ?")
    text = text.replace(" question", " ?")
    
    # Variantes pour point d'exclamation  
    text = text.replace(" point d'exclamation", " !")
    text = text.replace(" point exclamation", " !")
    text = text.replace(" exclamation", " !")
    
    # Point normal en dernier pour ne pas interférer
    text = text.replace(" point", ".")
    
    text = text.replace(" deux points", " :")
    text = text.replace(" point virgule", " ;")
    text = text.replace(" tiret", "-")
    
    # Parenthèses et guillemets
    text = text.replace(" parenthèse ouverte", " (")
    text = text.replace(" parenthèse fermée", ")")
    text = text.replace(" guillemet ouvrant", ' "')
    text = text.replace(" guillemet fermant", '"')
    text = text.replace(" apostrophe", "'")
    
    # Navigation et formatage
    text = text.replace(" nouvelle ligne", "\n")
    text = text.replace(" retour à la ligne", "\n")
    text = text.replace(" tabulation", "\t")
    text = text.replace(" espace", " ")
    
    # Expressions communes
    text = text.replace(" arobase", "@")
    text = text.replace(" diese", "#")
    text = text.replace(" pourcentage", "%")
    text = text.replace(" et commercial", "&")
    text = text.replace(" étoile", "*")
    text = text.replace(" plus", "+")
    text = text.replace(" égal", "=")
    text = text.replace(" moins", "-")
    text = text.replace(" divisé par", "/")
    text = text.replace(" barre oblique", "/")
    
    # Nettoyer les espaces en trop autour de certains signes
    text = text.replace(" ,", ",")
    text = text.replace(" .", ".")
    text = text.replace("( ", "(")
    text = text.replace(' "', '"')
    
    return text