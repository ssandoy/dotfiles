#Requires AutoHotkey v2.0
#SingleInstance Force

; Left Alt + key
<!o::SendText Chr(0x00F8)
<!e::SendText Chr(0x00E6)
<!a::SendText Chr(0x00E5)

<!+o::SendText Chr(0x00D8)
<!+e::SendText Chr(0x00C6)
<!+a::SendText Chr(0x00C5)

; Right Alt / AltGr + key
>!o::SendText Chr(0x00F8)
>!e::SendText Chr(0x00E6)
>!a::SendText Chr(0x00E5)

>!+o::SendText Chr(0x00D8)
>!+e::SendText Chr(0x00C6)
>!+a::SendText Chr(0x00C5)

; Some Windows layouts report Right Alt as AltGr.
<^>!o::SendText Chr(0x00F8)
<^>!e::SendText Chr(0x00E6)
<^>!a::SendText Chr(0x00E5)

<^>!+o::SendText Chr(0x00D8)
<^>!+e::SendText Chr(0x00C6)
<^>!+a::SendText Chr(0x00C5)
