// dynamic-sound-effect-instance.cs --- what does real XNA do with no playback
// device?
//
// The pinned IL takes the constructor as far as
// SoundEffectUnsafeNativeMethods::CreateDynamicSoundEffectInstance and then into
// native code. Helpers::GetExceptionFromResult maps that call's result, and two
// of its entries are candidates for "no device": 0x8ac70017 becomes
// NoAudioHardwareException, and 0x80040256 becomes InvalidOperationException
// carrying FrameworkResources.NoAudioPlaybackDevicesFound. This program records
// which one happens -- or that the constructor succeeds, which is what CNA does
// and what this binding currently adopts.
//
// See README.md for why it does not run under Wine, and what would make it run.

using System;
using System.IO;

static class XnaReferenceProbe
{
    const string OutputPath = @"C:\xna-reference-out.txt";

    static void Write(string line)
    {
        File.AppendAllText(OutputPath, line + "\r\n");
        Console.WriteLine(line);
    }

    static void Main()
    {
        Write("STAGE:start");
        // The assembly loads lazily, on first use of a type from it, so the
        // BadImageFormatException surfaces here rather than at startup -- which
        // is why the construction is in its own method behind its own catch.
        try
        {
            Construct();
        }
        catch (Exception loadFailure)
        {
            Write("LOAD:" + loadFailure.GetType().FullName);
            Write("MESSAGE:" + loadFailure.Message);
        }
        Write("STAGE:end");
    }

    static void Construct()
    {
        Write("STAGE:before-ctor");
        try
        {
            var instance = new Microsoft.Xna.Framework.Audio.DynamicSoundEffectInstance(
                44100, Microsoft.Xna.Framework.Audio.AudioChannels.Stereo);
            Write("RESULT:SUCCESS pending=" + instance.PendingBufferCount);
        }
        catch (Exception thrown)
        {
            Write("RESULT:EXCEPTION " + thrown.GetType().FullName);
            Write("MESSAGE:" + thrown.Message);
            Write("HRESULT:0x" + System.Runtime.InteropServices.Marshal
                                     .GetHRForException(thrown).ToString("X8"));
        }
    }
}
