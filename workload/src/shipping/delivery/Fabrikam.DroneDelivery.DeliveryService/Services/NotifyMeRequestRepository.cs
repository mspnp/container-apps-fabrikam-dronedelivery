// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Fabrikam.DroneDelivery.DeliveryService.Models;

namespace Fabrikam.DroneDelivery.DeliveryService.Services
{
    public class NotifyMeRequestRepository : INotifyMeRequestRepository
    {
        public async Task<IEnumerable<InternalNotifyMeRequest>> GetAllByDeliveryIdAsync(string deliveryId)
        {
            return await CosmosDBRepository<InternalNotifyMeRequest>.GetItemsAsync(n => n.DeliveryId == deliveryId, deliveryId.Substring(0, Constants.PartitionKeyLength));
        }

        public async Task AddAsync(InternalNotifyMeRequest notifyMeRequest)
        {
            await CosmosDBRepository<InternalNotifyMeRequest>.CreateItemAsync(notifyMeRequest, notifyMeRequest.DeliveryId.Substring(0, Constants.PartitionKeyLength));
        }
    }
}
