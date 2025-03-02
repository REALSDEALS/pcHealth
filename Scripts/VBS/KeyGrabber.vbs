' VBS-Helper function to get Windows version and activation information.
' Reason: Microsoft Windows won't allow us to read out the product key directly, so we need to convert that ourselves.
' Also: Microsoft hasn't made the necessary Registry changes when they introduced Windows 11,
' so we need to check the build number to determine if it's Windows 10 or Windows 11.
'
' This script is called: KeyGrabber.vbs

Option Explicit

' -------------------------------
' 1. Create Shell Object and Define Registry Path
' -------------------------------
Dim objShell, regPath, currentBuild, ProductName, ProductID, ProductKey, ProductData
Set objShell = CreateObject("WScript.Shell")
regPath = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\"

' -------------------------------
' 2. Read Current Build Number from Registry
' -------------------------------
currentBuild = CLng(objShell.RegRead(regPath & "CurrentBuild"))

' -------------------------------
' 3. Determine OS Name Based on Build Number
' -------------------------------
If currentBuild >= 22000 Then
    ProductName = "Windows 11 " & objShell.RegRead(regPath & "EditionID")
Else
    ProductName = objShell.RegRead(regPath & "ProductName")
End If

' -------------------------------
' 4. Read Product ID from Registry
' -------------------------------
ProductID = "Product ID: " & objShell.RegRead(regPath & "ProductID")

' -------------------------------
' 5. Read Digital Product ID and Convert to Readable Key
' -------------------------------
ProductKey = "Installed Key: " & ConvertToKey(objShell.RegRead(regPath & "DigitalProductId"))

' -------------------------------
' 6. Combine Product Information into One String
' -------------------------------
ProductData = "Windows Version: " & ProductName & vbNewLine & ProductID & vbNewLine & ProductKey

' -------------------------------
' 7. Prompt User to Save the Key to a File
' -------------------------------
If vbYes = MsgBox(ProductData & vbNewLine & vbNewLine & "Save your key to a file?", vbYesNo + vbQuestion, "pcHealth | Windows Key Grabber") Then
   Save ProductData
End If

' -------------------------------
' Function: ConvertToKey
' Converts the binary DigitalProductId into a human-readable product key
' -------------------------------
Function ConvertToKey(Key)
    Const KeyOffset = 52
    Dim isWin8, Maps, i, j, Current, KeyOutput, Last, keyPart1, insert

    ' Determine if the OS is Windows 8 (or newer) based on the key data
    isWin8 = (Key(66) \ 6) And 1
    Key(66) = (Key(66) And &HF7) Or ((isWin8 And 2) * 4)
    
    i = 24
    Maps = "BCDFGHJKMPQRTVWXY2346789"
    KeyOutput = ""
    
    ' Loop through the key bytes to decode the product key
    Do 
        Current = 0
        j = 14
        Do 
            Current = Current * 256
            Current = Key(j + KeyOffset) + Current
            Key(j + KeyOffset) = (Current \ 24)
            Current = Current Mod 24
            j = j - 1
        Loop While j >= 0
        i = i - 1
        ' Prepend the corresponding character from Maps to KeyOutput
        KeyOutput = Mid(Maps, Current + 1, 1) & KeyOutput
        Last = Current
    Loop While i >= 0
    
    ' Adjust the output for Windows 8 and later
    If isWin8 = 1 Then
        keyPart1 = Mid(KeyOutput, 2, Last)
        insert = "N"
        KeyOutput = Replace(KeyOutput, keyPart1, keyPart1 & insert, 2, 1, 0)
        If Last = 0 Then KeyOutput = insert & KeyOutput
    End If
    
    ' Insert dashes to format the key in groups of 5 characters
    ConvertToKey = Mid(KeyOutput, 1, 5) & "-" & _
                    Mid(KeyOutput, 6, 5) & "-" & _
                    Mid(KeyOutput, 11, 5) & "-" & _
                    Mid(KeyOutput, 16, 5) & "-" & _
                    Mid(KeyOutput, 21, 5)
End Function

' -------------------------------
' Function: Save
' Saves the provided data to a text file on the user's desktop
' -------------------------------
Function Save(Data)
    Dim fso, fName, txt, objShell, UserName
    Set objShell = CreateObject("WScript.Shell")
    ' Get the current user name from environment variables
    UserName = objShell.ExpandEnvironmentStrings("%UserName%")
    ' Define the file path on the desktop
    fName = "C:\Users\" & UserName & "\Desktop\KeyGrabber - pcHealth.txt"
    Set fso = CreateObject("Scripting.FileSystemObject")
    ' Create the text file and write the data into it
    Set txt = fso.CreateTextFile(fName)
    txt.WriteLine Data
    txt.Close
End Function
