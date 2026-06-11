// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Fabrikam.DroneDelivery.Common;
using Fabrikam.DroneDelivery.DeliveryService.Controllers;
using Fabrikam.DroneDelivery.DeliveryService.Models;
using Fabrikam.DroneDelivery.DeliveryService.Services;
using Moq;
using Xunit;

namespace Fabrikam.DroneDelivery.DeliveryService.Tests
{
    public class DeliveriesControllerFixture
    {
        private static UserAccount userAccount = new UserAccount("userid", "accountid");

        private static InternalDelivery delivery = new InternalDelivery("deliveryid",
                                        userAccount,
                                        new Location(0, 0, 0),
                                        new Location(1, 1, 1),
                                        "deadline",
                                        false,
                                        ConfirmationType.FingerPrint,
                                        "droneid");
        [Fact]
        public async Task Get_Returns404_IfDeliveryIdNotValid()
        {
            // Arrange
            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(new Mock<IDeliveryRepository>().Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            // Act
            var result = await target.Get("invaliddeliveryid") as NotFoundResult;

            // Assert
            Assert.NotNull(result);
            Assert.Equal(404, result.StatusCode);
        }

        [Fact]
        public async Task GetOwner_Returns404_IfDeliveryIdNotValid()
        {
            // Arrange
            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(new Mock<IDeliveryRepository>().Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            // Act
            var result = await target.GetOwner("invaliddeliveryid") as NotFoundResult;

            // Assert
            Assert.NotNull(result);
            Assert.Equal(404, result.StatusCode);
        }

        [Fact]
        public async Task GetOwner_ReturnsOwner()
        {
            // Arrange
            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.GetAsync(It.IsAny<string>()))
                                .ReturnsAsync(delivery);

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            // Act
            var result = await target.GetOwner("deliveryid") as OkObjectResult;

            // Assert
            Assert.NotNull(result);
            Assert.Equal(userAccount, result.Value);
        }

        [Fact]
        public async Task GetStatus_Returns404_IfDeliveryIdNotValid()
        {
            // Arrange
            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(new Mock<IDeliveryRepository>().Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            // Act
            var result = await target.GetStatus("invaliddeliveryid") as NotFoundResult;

            // Assert
            Assert.NotNull(result);
            Assert.Equal(404, result.StatusCode);
        }

        [Fact]
        public async Task Put_Returns204_IfDeliveryIdExists()
        {
            // Arrange
            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.CreateAsync(It.IsAny<InternalDelivery>())).Throws(new DuplicateResourceException("dupe", null));
            deliveryRepository.Setup(r => r.UpdateAsync(It.IsAny<string>(), It.IsAny<InternalDelivery>())).Returns(Task.CompletedTask);

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>()))
                         .Returns(new Mock<ILogger<DeliveriesController>>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            // Act
            var result = await target.Put(new Delivery("existingdeliveryid", new UserAccount("user", "account"), new Location(0, 0, 0), new Location(2, 2, 2), "deadline", true, ConfirmationType.FingerPrint, "drone"), "existingdeliveryid");
            var statusCodeResult = (StatusCodeResult)result;

            // Assert
            Assert.NotNull(statusCodeResult);
            Assert.Equal(204, statusCodeResult.StatusCode);
        }

        [Fact]
        public async Task Put_AddsToCache()
        {
            // Arrange
            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.CreateAsync(It.IsAny<InternalDelivery>())).Returns(Task.CompletedTask);

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);
            // Act
            var result = await target.Put(new Delivery("deliveryid", new UserAccount("user", "account"), new Location(0, 0, 0), new Location(2, 2, 2), "deadline", true, ConfirmationType.FingerPrint, "drone"), "deliveryid");
            var createdAtRouteResult = (CreatedAtRouteResult)result;

            // Assert
            Assert.Equal(201, createdAtRouteResult.StatusCode);
            Assert.NotNull(createdAtRouteResult.Value);
            deliveryRepository.VerifyAll();
        }

        [Fact]
        public async Task Put_AddscreatedDeliveryEvent()
        {
            // Arrange
            DeliveryTrackingEvent createdDelivery = null;
            var deliveryStatusEventRepository = new Mock<IDeliveryTrackingEventRepository>();
            deliveryStatusEventRepository.Setup(r => r.AddAsync(It.IsAny<DeliveryTrackingEvent>()))
                                         .Returns(Task.CompletedTask)
                                         .Callback<DeliveryTrackingEvent>(e => createdDelivery = e);

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(new Mock<IDeliveryRepository>().Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  deliveryStatusEventRepository.Object,
                                                  loggerFactory.Object);
            // Act
            var result = await target.Put(new Delivery("deliveryid", new UserAccount("user", "account"), new Location(0, 0, 0), new Location(2, 2, 2), "deadline", true, ConfirmationType.FingerPrint, "drone"), "deliveryid");
            var createdAtRouteResult = (CreatedAtRouteResult)result;

            // Assert
            Assert.Equal(201, createdAtRouteResult.StatusCode);
            Assert.NotNull(createdAtRouteResult.Value);
            Assert.NotNull(createdDelivery);
            Assert.Equal(DeliveryStage.Created, createdDelivery.Stage);
            deliveryStatusEventRepository.VerifyAll();
        }

        [Fact]
        public async Task Patch_Returns404_IfDeliveryIdNotValid()
        {
            // Arrange
            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(new Mock<IDeliveryRepository>().Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            // Act
            var result = await target.Patch("invaliddeliveryid", null) as NotFoundResult;


            // Assert
            Assert.NotNull(result);
            Assert.Equal(404, result.StatusCode);
        }

        [Fact]
        public async Task Patch_UpdatesCache()
        {
            // Arrange
            InternalDelivery updatedDelivery = null;
            var rescheduledDelivery = new RescheduledDelivery(new Location(2, 2, 2),
                                                              new Location(3, 3, 3),
                                                              "newdeadline");

            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.GetAsync("deliveryid")).ReturnsAsync(delivery);
            deliveryRepository.Setup(r => r.UpdateAsync("deliveryid", It.IsAny<InternalDelivery>()))
                              .Returns(Task.CompletedTask)
                              .Callback((string i, InternalDelivery d) => updatedDelivery = d);

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            // Act
            await target.Patch("deliveryid", rescheduledDelivery);

            // Assert
            //unchanged values
            Assert.Equal("deliveryid", updatedDelivery.Id);
            Assert.Equal("userid", updatedDelivery.Owner.UserId);

            //updated values
            Assert.Equal(2, updatedDelivery.Pickup.Altitude);
            Assert.Equal(3, updatedDelivery.Dropoff.Altitude);
            Assert.Equal("newdeadline", updatedDelivery.Deadline);

            deliveryRepository.VerifyAll();
        }

        [Fact]
        public async Task Patch_AddsRescheduledDeliveryEvent()
        {
            // Arrange
            DeliveryTrackingEvent deliveryTrackingEvent = null;

            var rescheduledDelivery = new RescheduledDelivery(new Location(2, 2, 2),
                                                              new Location(3, 3, 3),
                                                              "newdeadline");

            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.GetAsync("deliveryid")).ReturnsAsync(delivery);

            var deliveryStatusEventRepository = new Mock<IDeliveryTrackingEventRepository>();
            deliveryStatusEventRepository.Setup(r => r.AddAsync(It.IsAny<DeliveryTrackingEvent>()))
                                         .Returns(Task.CompletedTask)
                                         .Callback<DeliveryTrackingEvent>(e => deliveryTrackingEvent = e);

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  deliveryStatusEventRepository.Object,
                                                  loggerFactory.Object);

            // Act
            var result = await target.Patch("deliveryid", rescheduledDelivery) as OkResult;

            // Assert
            Assert.NotNull(result);
            Assert.NotNull(deliveryTrackingEvent);
            Assert.Equal(DeliveryStage.Rescheduled, deliveryTrackingEvent.Stage);
            deliveryStatusEventRepository.VerifyAll();
        }

        [Fact]
        public async Task Delete_Returns404_IfDeliveryIdNotValid()
        {
            // Arrange
            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(new Mock<IDeliveryRepository>().Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            // Act
            var result = await target.Delete("invaliddeliveryid") as NotFoundResult;

            // Assert
            Assert.NotNull(result);
            Assert.Equal(404, result.StatusCode);
        }

        [Fact]
        public async Task Delete_SendsMessageWithCancelledTrackingEvent()
        {
            // Arrange
            DeliveryTrackingEvent cancelledDelivery = null;

            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.GetAsync("deliveryid")).ReturnsAsync(delivery);

            var deliveryStatusEventRepository = new Mock<IDeliveryTrackingEventRepository>();
            deliveryStatusEventRepository.Setup(r => r.AddAsync(It.IsAny<DeliveryTrackingEvent>()))
                                         .Returns(Task.CompletedTask)
                                         .Callback<DeliveryTrackingEvent>(e => cancelledDelivery = e);

            deliveryStatusEventRepository.Setup(r => r.GetByDeliveryIdAsync("deliveryid"))
                                         .ReturnsAsync(new ReadOnlyCollection<DeliveryTrackingEvent>(new List<DeliveryTrackingEvent>() { cancelledDelivery }));

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  deliveryStatusEventRepository.Object,
                                                  loggerFactory.Object);
            // Act
            await target.Delete("deliveryid");

            // Assert
            Assert.NotNull(cancelledDelivery);
            Assert.Equal("deliveryid", cancelledDelivery.DeliveryId);
            Assert.Equal(DeliveryStage.Cancelled, cancelledDelivery.Stage);
            deliveryRepository.VerifyAll();
        }

        [Fact]
        public async Task NotifyMe_Returns404_IfDeliveryIdNotValid()
        {
            // Arrange
            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(new Mock<IDeliveryRepository>().Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            // Act
            var result = await target.NotifyMe("invaliddeliveryid", null) as NotFoundResult;

            // Assert
            Assert.NotNull(result);
            Assert.Equal(404, result.StatusCode);
        }

        [Fact]
        public async Task NotifyMe_AddsNotifyMeRequest()
        {
            // Arrange
            InternalNotifyMeRequest savedNotifyMeRequest = null;

            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.GetAsync("deliveryid")).ReturnsAsync(delivery);

            var notifyMeRequestRepository = new Mock<INotifyMeRequestRepository>();
            notifyMeRequestRepository.Setup(r => r.AddAsync(It.IsAny<InternalNotifyMeRequest>()))
                                     .Returns(Task.CompletedTask)
                                     .Callback<InternalNotifyMeRequest>(r => savedNotifyMeRequest = r);

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  notifyMeRequestRepository.Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            var notifyMeRequest = new NotifyMeRequest("email@test.com", "1234567");

            // Act
            var result = await target.NotifyMe("deliveryid", notifyMeRequest) as NoContentResult;

            // Assert
            Assert.NotNull(result);
            Assert.Equal("deliveryid", savedNotifyMeRequest.DeliveryId);
            Assert.Equal("email@test.com", savedNotifyMeRequest.EmailAddress);
            Assert.Equal("1234567", savedNotifyMeRequest.SMS);
        }

        [Fact]
        public async Task Confirm_Returns404_IfDeliveryIdNotValid()
        {
            // Arrange
            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(new Mock<IDeliveryRepository>().Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);
            // Act
            var result = await target.Confirm("invaliddeliveryid", null) as NotFoundResult;

            // Assert
            Assert.NotNull(result);
            Assert.Equal(404, result.StatusCode);
        }

        [Fact]
        public async Task Confirm_SendsNotifications()
        {
            // Arrange
            DeliveryTrackingEvent completedDelivery = null;

            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.GetAsync("deliveryid")).ReturnsAsync(delivery);

            var notifyMeRequests = new List<InternalNotifyMeRequest>();
            notifyMeRequests.Add(new InternalNotifyMeRequest
            { DeliveryId = "deliveryid", EmailAddress = "email1@test.com", SMS = "1111111" });
            notifyMeRequests.Add(new InternalNotifyMeRequest
            { DeliveryId = "deliveryid", EmailAddress = "email2@test.com", SMS = "2222222" });
            var notifyMeRequestRepository = new Mock<INotifyMeRequestRepository>();
            notifyMeRequestRepository.Setup(r => r.GetAllByDeliveryIdAsync("deliveryid"))
                                     .ReturnsAsync(notifyMeRequests);

            int notificationServiceCalled = 0;
            var notificationService = new Mock<INotificationService>();
            notificationService.Setup(s => s.SendNotificationsAsync(It.IsAny<InternalNotifyMeRequest>()))
                               .Returns(Task.CompletedTask)
                               .Callback(() => notificationServiceCalled++);


            var deliveryStatusEventRepository = new Mock<IDeliveryTrackingEventRepository>();

            deliveryStatusEventRepository.Setup(r => r.GetByDeliveryIdAsync("deliveryid"))
                                         .ReturnsAsync(new ReadOnlyCollection<DeliveryTrackingEvent>(new List<DeliveryTrackingEvent>() { completedDelivery }));

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  notifyMeRequestRepository.Object,
                                                  notificationService.Object,
                                                  deliveryStatusEventRepository.Object,
                                                  loggerFactory.Object);

            var confirmation = new Confirmation(new DateTimeStamp("datetimevalue"),
                                                                    new Location(1, 2, 3),
                                                                    ConfirmationType.Picture,
                                                                    "confirmationblob");
            // Acts
            var result = await target.Confirm("deliveryid", confirmation) as OkResult;

            // Assert
            Assert.NotNull(result);
            Assert.Equal(2, notificationServiceCalled);
        }

        [Fact]
        public async Task Confirm_DeletesDeliveryLogically()
        {
            // Arrange
            InternalDelivery confirmedDelivery = null;
            DeliveryTrackingEvent completedDelivery = null;

            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.GetAsync("deliveryid")).ReturnsAsync(delivery);
            deliveryRepository.Setup(r => r.DeleteAsync("deliveryid", It.IsAny<InternalDelivery>()))
                            .Returns(Task.CompletedTask)
                            .Callback<string, InternalDelivery>((i, d) => confirmedDelivery = d);

            var deliveryStatusEventRepository = new Mock<IDeliveryTrackingEventRepository>();
            deliveryStatusEventRepository.Setup(r => r.AddAsync(It.IsAny<DeliveryTrackingEvent>()))
                                         .Returns(Task.CompletedTask)
                                         .Callback<DeliveryTrackingEvent>(e => completedDelivery = e);

            deliveryStatusEventRepository.Setup(r => r.GetByDeliveryIdAsync("deliveryid"))
                                         .ReturnsAsync(new ReadOnlyCollection<DeliveryTrackingEvent>(new List<DeliveryTrackingEvent>() { completedDelivery }));

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  deliveryStatusEventRepository.Object,
                                                  loggerFactory.Object);
            var location = new Location(1, 2, 3);
            var confirmation = new Confirmation(new DateTimeStamp("datetimevalue"),
                                                        location,
                                                        ConfirmationType.Picture,
                                                        "confirmationblob");

            // Act
            var result = await target.Confirm("deliveryid", confirmation) as OkResult;

            // Assert
            Assert.NotNull(result);
            deliveryRepository.Verify(r => r.DeleteAsync("deliveryid", confirmedDelivery));
            Assert.Equal(location, confirmedDelivery.Dropoff);
        }

        [Fact]
        public async Task Confirm_AddsDeliveryCompletedEvent()
        {
            // Arrange
            DeliveryTrackingEvent completedDelivery = null;

            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.GetAsync("deliveryid")).ReturnsAsync(delivery);

            var deliveryStatusEventRepository = new Mock<IDeliveryTrackingEventRepository>();
            deliveryStatusEventRepository.Setup(r => r.AddAsync(It.IsAny<DeliveryTrackingEvent>()))
                                         .Returns(Task.CompletedTask)
                                         .Callback<DeliveryTrackingEvent>(e => completedDelivery = e);

            deliveryStatusEventRepository.Setup(r => r.GetByDeliveryIdAsync("deliveryid"))
                                         .ReturnsAsync(new ReadOnlyCollection<DeliveryTrackingEvent>(new List<DeliveryTrackingEvent>() { completedDelivery }));

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  deliveryStatusEventRepository.Object,
                                                  loggerFactory.Object);

            var confirmation = new Confirmation(new DateTimeStamp("datetimevalue"),
                                                        new Location(1, 2, 3),
                                                        ConfirmationType.Picture,
                                                        "confirmationblob");

            // Act
            var result = await target.Confirm("deliveryid", confirmation) as OkResult;

            // Assert
            Assert.NotNull(result);
            Assert.NotNull(completedDelivery);
            Assert.Equal(DeliveryStage.Completed, completedDelivery.Stage);
        }

        [Fact]
        public async Task GetSummry_ReturnsSummary()
        {
            const int TestDeliveryCount = 5000;

            // Arrange
            var deliveryRepository = new Mock<IDeliveryRepository>();
            deliveryRepository.Setup(r => r.GetDeliveryCountAsync("owner", 2019, 01))
                                .ReturnsAsync(TestDeliveryCount)
                                .Verifiable();

            var loggerFactory = new Mock<ILoggerFactory>();
            loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(new Mock<ILogger>().Object);

            var target = new DeliveriesController(deliveryRepository.Object,
                                                  new Mock<INotifyMeRequestRepository>().Object,
                                                  new Mock<INotificationService>().Object,
                                                  new Mock<IDeliveryTrackingEventRepository>().Object,
                                                  loggerFactory.Object);

            // Act
            var result = await target.GetSummary("owner", 2019, 01) as OkObjectResult;

            // Assert
            Assert.NotNull(result);
            var summary = Assert.IsType<DeliveriesSummary>(result.Value);
            Assert.Equal(TestDeliveryCount, summary.Count);
            deliveryRepository.VerifyAll();
        }
    }
}
