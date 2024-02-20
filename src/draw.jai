// Vulk
// Draw
// February 2024

draw_frame :: () {
    //print("Frame %\n", frame_index);

    u64_low, u64_high := get_integer_range(u64);

    frame_index += 1;
    index := frame_index % FRAME_COUNT;
    vkWaitForFences(device, 1, *frameFences[index], VK_TRUE, u64_high);
    vkResetFences(device, 1, *frameFences[index]);

    imageIndex: u32;
    vkAcquireNextImageKHR(device, swapchain, u64_high, imageAvailableSemaphores[index], VK_NULL_HANDLE, *imageIndex);

    beginInfo: VkCommandBufferBeginInfo;
    beginInfo.flags = .ONE_TIME_SUBMIT_BIT;

    vkBeginCommandBuffer(commandBuffers[index], *beginInfo);

    // @@ ...


    // Clear frame.
    subResourceRange : VkImageSubresourceRange;
    {
        using subResourceRange;
        aspectMask     = .COLOR_BIT;
        baseMipLevel   = 0;
        levelCount     = VK_REMAINING_MIP_LEVELS;
        baseArrayLayer = 0;
        layerCount     = VK_REMAINING_ARRAY_LAYERS;
    }
    
    // Change layout of image to be optimal for clearing
    imgMemoryBarrier : VkImageMemoryBarrier;
    {
        using imgMemoryBarrier;
        srcAccessMask       = 0;
        dstAccessMask       = .TRANSFER_WRITE_BIT;
        oldLayout           = .UNDEFINED;
        newLayout           = .TRANSFER_DST_OPTIMAL;
        srcQueueFamilyIndex = queue_family_index;
        dstQueueFamilyIndex = queue_family_index;
        image               = swapchainImages[imageIndex];
        subresourceRange    = subResourceRange;
    }
    
    vkCmdPipelineBarrier(commandBuffers[index], .TRANSFER_BIT, .TRANSFER_BIT, 
                         0, 0, null, 0, null, 1, *imgMemoryBarrier);

    clearColor : VkClearColorValue;
    {
        // Pick a color with which to clear the screen.
        color1 := Vector4.{1,  1, 0, 1};
        color2 := Vector4.{.5, 0, 1, 1};

        now := seconds_since_init();
        t := cos(cast(float) now) * .5 + .5;
        Clamp(*t, 0, 1);
        color := lerp(color1, color2, t);
        clearColor._float32 = color.component;
        //clearColor._float32 = float.[1, 1, 0, 1];
    }
    
    vkCmdClearColorImage(commandBuffers[index], swapchainImages[imageIndex], .TRANSFER_DST_OPTIMAL, *clearColor, 1, *subResourceRange);

    // Change layout of image to be optimal for presenting
    imgMemoryBarrier.srcAccessMask = .TRANSFER_WRITE_BIT;
    imgMemoryBarrier.dstAccessMask = .MEMORY_READ_BIT;
    imgMemoryBarrier.oldLayout     = .TRANSFER_DST_OPTIMAL;
    imgMemoryBarrier.newLayout     = .PRESENT_SRC_KHR;
    //imgMemoryBarrier.srcQueueFamilyIndex = queue_family_index;
    //imgMemoryBarrier.dstQueueFamilyIndex = queue_family_index;
    //imgMemoryBarrier.image = swapchainImages[imageIndex];
    //imgMemoryBarrier.subresourceRange = subResourceRange;
    vkCmdPipelineBarrier(commandBuffers[index], .TRANSFER_BIT, .BOTTOM_OF_PIPE_BIT,
        0, 0, null, 0, null, 1, *imgMemoryBarrier);


    vkEndCommandBuffer(commandBuffers[index]);

    submitInfo: VkSubmitInfo; 
    submitInfo.waitSemaphoreCount   = 1;
    submitInfo.pWaitSemaphores      = *imageAvailableSemaphores[index];
    submitInfo.pWaitDstStageMask    = VkPipelineStageFlags.[.COLOR_ATTACHMENT_OUTPUT_BIT].data;
    submitInfo.commandBufferCount   = 1;
    submitInfo.pCommandBuffers      = *commandBuffers[index];
    submitInfo.signalSemaphoreCount = 1;
    submitInfo.pSignalSemaphores    = *renderFinishedSemaphores[index];
    vkQueueSubmit(queue, 1, *submitInfo, frameFences[index]);

    // Present.
    presentInfo: VkPresentInfoKHR;
    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores    = *renderFinishedSemaphores[index];
    presentInfo.swapchainCount     = 1;
    presentInfo.pSwapchains        = *swapchain;
    presentInfo.pImageIndices      = *imageIndex;
    vkQueuePresentKHR(queue, *presentInfo);
}
