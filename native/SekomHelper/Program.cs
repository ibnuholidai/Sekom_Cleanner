using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

internal sealed class FolderResult
{
    public string Name { get; set; } = "";
    public string Path { get; set; } = "";
    public bool Exists { get; set; }
    public long SizeBytes { get; set; }
}

internal static class Program
{
    private static long GetDirectorySize(string rootPath)
    {
        long total = 0;

        if (string.IsNullOrWhiteSpace(rootPath) || !Directory.Exists(rootPath))
            return 0;

        var stack = new Stack<string>();
        stack.Push(rootPath);

        while (stack.Count > 0)
        {
            var current = stack.Pop();

            // Enumerate files
            try
            {
                string[] files = Array.Empty<string>();
                try { files = Directory.GetFiles(current); } catch { /* ignore */ }
                foreach (var f in files)
                {
                    try
                    {
                        var fi = new FileInfo(f);
                        total += fi.Length;
                    }
                    catch { /* ignore individual file errors */ }
                }
            }
            catch { /* ignore directory errors */ }

            // Enumerate subdirectories
            try
            {
                string[] subdirs = Array.Empty<string>();
                try { subdirs = Directory.GetDirectories(current); } catch { /* ignore */ }
                foreach (var d in subdirs)
                {
                    stack.Push(d);
                }
            }
            catch { /* ignore */ }
        }

        return total;
    }

    private static int Main(string[] args)
    {
        try
        {
            // Default 6 known folders under user profile
            string user = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            var names = new[] { "3D Objects", "Documents", "Downloads", "Music", "Pictures", "Videos" };

            var results = new ConcurrentBag<FolderResult>();

            // Moderate parallelism to keep UI responsive and avoid overwhelming disk
            var po = new ParallelOptions { MaxDegreeOfParallelism = Math.Max(2, Environment.ProcessorCount - 1) };
            Parallel.ForEach(names, po, name =>
            {
                string path = System.IO.Path.Combine(user, name);
                bool exists = Directory.Exists(path);
                long size = 0;
                if (exists)
                {
                    try
                    {
                        size = GetDirectorySize(path);
                    }
                    catch
                    {
                        size = 0;
                    }
                }

                results.Add(new FolderResult
                {
                    Name = name,
                    Path = path,
                    Exists = exists,
                    SizeBytes = size
                });
            });

            // Preserve original order
            var ordered = results.OrderBy(r => Array.IndexOf(names, r.Name)).ToArray();

            Console.OutputEncoding = System.Text.Encoding.UTF8;
            Console.WriteLine(JsonSerializer.Serialize(ordered, new JsonSerializerOptions
            {
                WriteIndented = false
            }));

            return 0;
        }
        catch
        {
            return 1;
        }
    }
}
