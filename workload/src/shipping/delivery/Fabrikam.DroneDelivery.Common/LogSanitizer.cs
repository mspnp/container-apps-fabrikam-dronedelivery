// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Fabrikam.DroneDelivery.Common
{
    public static class LogSanitizer
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
                switch (character)
                {
                    case '\r':
                        sanitizedValue.Append("\\r");
                        break;
                    case '\n':
                        sanitizedValue.Append("\\n");
                        break;
                    case '\t':
                        sanitizedValue.Append("\\t");
                        break;
                    default:
                        sanitizedValue.Append(char.IsControl(character) ? '?' : character);
                        break;
                }
            }

            return sanitizedValue.ToString();
        }

        public static IEnumerable<string> SanitizeValues(IEnumerable<string> values)
        {
            return values?.Select(Sanitize);
        }
    }
}