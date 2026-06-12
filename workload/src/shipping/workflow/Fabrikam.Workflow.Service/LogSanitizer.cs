// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

using System.Text;

namespace Fabrikam.Workflow.Service
{
    internal static class LogSanitizer
    {
        public static string Sanitize(string value)
        {
            if (value == null)
            {
                return null;
            }

            var sanitizedValue = new StringBuilder(value.Length);
            foreach (var character in value)
            {
                if (character == '\r')
                {
                    sanitizedValue.Append("\\r");
                }
                else if (character == '\n')
                {
                    sanitizedValue.Append("\\n");
                }
                else if (character == '\t')
                {
                    sanitizedValue.Append("\\t");
                }
                else
                {
                    sanitizedValue.Append(char.IsControl(character) ? '?' : character);
                }
            }

            return sanitizedValue.ToString();
        }
    }
}