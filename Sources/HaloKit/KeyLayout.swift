import Carbon.HIToolbox

/// Built-in shortcuts (⌘C, ⌘V, the app rings' presets) are written as keys on a US keyboard.
/// Apps match shortcuts by the character a key types, so on Dvorak or AZERTY the same key
/// would press the wrong shortcut. These map a shortcut to the key that types the same
/// character on whatever layout is active. Shortcuts the user records are already in their
/// layout and never go through here.
public enum KeyLayout {
    /// What each US key types, for the keys built-in shortcuts use.
    static let usCharacters: [Int: Character] = {
        var map: [Int: Character] = [
            kVK_ANSI_Grave: "`", kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[",
            kVK_ANSI_RightBracket: "]", kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'",
            kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
        ]
        let letters: [(Int, Character)] = [
            (kVK_ANSI_A, "a"), (kVK_ANSI_B, "b"), (kVK_ANSI_C, "c"), (kVK_ANSI_D, "d"), (kVK_ANSI_E, "e"),
            (kVK_ANSI_F, "f"), (kVK_ANSI_G, "g"), (kVK_ANSI_H, "h"), (kVK_ANSI_I, "i"), (kVK_ANSI_J, "j"),
            (kVK_ANSI_K, "k"), (kVK_ANSI_L, "l"), (kVK_ANSI_M, "m"), (kVK_ANSI_N, "n"), (kVK_ANSI_O, "o"),
            (kVK_ANSI_P, "p"), (kVK_ANSI_Q, "q"), (kVK_ANSI_R, "r"), (kVK_ANSI_S, "s"), (kVK_ANSI_T, "t"),
            (kVK_ANSI_U, "u"), (kVK_ANSI_V, "v"), (kVK_ANSI_W, "w"), (kVK_ANSI_X, "x"), (kVK_ANSI_Y, "y"),
            (kVK_ANSI_Z, "z"), (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"), (kVK_ANSI_3, "3"),
            (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"), (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"), (kVK_ANSI_8, "8"),
            (kVK_ANSI_9, "9"),
        ]
        for (code, char) in letters { map[code] = char }
        return map
    }()

    /// `lookup` gives the key that types a character on the active layout, and whether it
    /// needs Shift. Keys like Return, arrows and F-keys aren't characters and pass through.
    public static func translate(_ combo: KeyCombo, lookup: (Character) -> (keyCode: Int, shift: Bool)?) -> KeyCombo {
        guard let character = usCharacters[combo.keyCode], let key = lookup(character) else { return combo }
        var modifiers = combo.modifiers
        if key.shift { modifiers.insert(.shift) }
        return KeyCombo(key.keyCode, modifiers)
    }

    public static func translate(_ combo: KeyCombo) -> KeyCombo {
        translate(combo, lookup: currentLayoutKey)
    }

    /// Asks the active keyboard layout which key types `character`, trying unshifted keys first.
    public static func currentLayoutKey(for character: Character) -> (keyCode: Int, shift: Bool)? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        let target = String(character)
        return data.withUnsafeBytes { raw -> (keyCode: Int, shift: Bool)? in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for shift in [false, true] {
                let modifierState = UInt32(shift ? (shiftKey >> 8) & 0xFF : 0)
                for code in 0..<128 {
                    var deadKeys: UInt32 = 0
                    var length = 0
                    var chars = [UniChar](repeating: 0, count: 4)
                    let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDown), modifierState,
                                                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                                &deadKeys, chars.count, &length, &chars)
                    if status == noErr, length > 0, String(utf16CodeUnits: chars, count: length).lowercased() == target {
                        return (code, shift)
                    }
                }
            }
            return nil
        }
    }
}
