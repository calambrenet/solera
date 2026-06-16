# Solera Linux - logo ASCII (el sol de la solera) para `screenfetch -a`.
# screenfetch hace: printf "${fulloutput[i]}$c0\n" "$info" — cada entrada es
# un FORMAT de printf: termina en %s y los % literales van escapados como %%.
# Color oro (paleta de Solera). No editar a mano: regenerar desde el arte.
gold=$'\033[1;38;5;221m'
labelcolor=$'\033[1;38;5;221m'
textcolor=$'\033[0;38;5;223m'
startline="0"
logowidth="56"
fulloutput=(
"${gold}                           ==                           %s"
"${gold}                          ::::                          %s"
"${gold}               =::-       =::=       -::+               %s"
"${gold}               ::::                  ::::               %s"
"${gold}                 #                    #                 %s"
"${gold}                                                        %s"
"${gold}        -:=                                  -:-        %s"
"${gold}       -:::*           +::::::::-           +:::-       %s"
"${gold}        *-          #::::::::::::::#         #-#        %s"
"${gold}                   :::::-%%%%%%%%%%%%-:::::                   %s"
"${gold}                 %%::::#%%%%%%%%%%%%%%%%%%%%#::::%%                 %s"
"${gold}                 ::::%%%%%%%%%%%%%%%%%%%%%%%%%%%%::::                 %s"
"${gold}    +:::        *:::+%%%%%%%%%%%%%%%%%%%%%%%%%%%%+:::%%        :::+    %s"
"${gold}    -:::=       *:::#%%%%%%%%%%%%%%%%%%%%%%%%%%%%*:::#       =:::-    %s"
"${gold}                *::::%%%%%%%%%%%%%%%%%%%%%%%%%%%%::::                 %s"
"${gold}                 -:::-%%%%%%%%%%%%%%%%%%%%%%%%-:::=                 %s"
"${gold}                  -::::+%%%%%%%%%%%%%%%%=::::=                  %s"
"${gold}                   *::::::::::::::::                    %s"
"${gold}       -:::*          -::::::::::-          *:::-       %s"
"${gold}       -:::*                                *:::-       %s"
"${gold}                                                        %s"
"${gold}                                                        %s"
"${gold}               =::-                  -::=               %s"
"${gold}               ::::                  ::::               %s"
"${gold}                          ::::                          %s"
"${gold}                          -::-                          %s"
)
