# The XNA reference probe

**Purpose.** Two members of this binding are `QUALIFICATION_LIMIT` — reported
partial not because anything is unimplemented but because *XNA's own answer has
never been observed*:

* `DynamicSoundEffectInstance.new(Int32, AudioChannels)` — what XNA does when
  there is no playback device. The pinned IL carries the whole constructor and
  the whole `HRESULT`-to-exception table; the one unknown is which code the
  native `CreateDynamicSoundEffectInstance` returns with no device.
* `Texture2D.FromStream(GraphicsDevice, Stream)` — whether XNA's image
  operation 0 *enlarges* an image smaller than the profile's `MaxTextureSize`,
  which happens inside `XnaImaging.DecodeStreamToTexture`.

Both live in native x86 inside the mixed-mode `Microsoft.Xna.Framework.dll`, so
no disassembly of IL can answer them. Only running real XNA can. This directory
is the attempt, kept so that the next agent does not have to rediscover either
that it was tried or how far it got.

**Expected outcome, measured 2026-09-07 and still the outcome to expect.** The
probe *compiles* against the pinned assembly and *fails to load* it:

    System.BadImageFormatException: Could not load file or assembly
    'Microsoft.Xna.Framework, Version=4.0.0.0, Culture=neutral,
    PublicKeyToken=842cf8be1de50553' or one of its dependencies. Bad format.

A mixed-mode (C++/CLI) assembly needs the Windows CLR's own image loader, which
Wine's does not fully provide. **A pass would not by itself settle either
member**: under Wine the mixer is FAudio and the device is Wine's D3D9, so a
result would be a reimplementation's rather than XNA's. What would settle them is
a real Windows host with the XNA 4.0 redistributable — and this probe is then the
program to run on it.

**Invocation.** Needs a Wine prefix with Microsoft .NET Framework 4.0 (or a real
Windows host, where `csc.exe` and the probe run directly), and a copy of the
pinned `Microsoft.Xna.Framework.dll` — identified by SHA-256, never by filename,
per `tools/api-compat/reference/XNA_IL_PROVENANCE.md`:

    sha256sum Microsoft.Xna.Framework.dll
    # must print 38e7093f52d7474bbc6256906519781a1210d7da50a1c667b52716fcf49ca130

    cp /path/to/Microsoft.Xna.Framework.dll build-probe/pf-xna-ref/
    cd build-probe/pf-xna-ref
    csc=~/.wine/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/csc.exe
    wine "$csc" /nologo /target:exe /out:probe.exe \
        /r:Microsoft.Xna.Framework.dll dynamic-sound-effect-instance.cs
    wine probe.exe          # writes C:\xna-reference-out.txt

The probe writes to a file rather than the console because Wine's console
redirection is unreliable enough to look like a hang.

**No Microsoft binary is stored in this repository**, and none is distributed
with it. Only the probe source and the hashes are committed.
