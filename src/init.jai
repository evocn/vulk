// Vulk
// Init
// February 2024

init :: () {
    print_available_vulkan_extensions();

    // Init Vulkan
    ////////////////////////////////////////////////////////////////////////////////
    {
        result : VkResult = .ERROR_INITIALIZATION_FAILED;

        // Application Info
        app_info: VkApplicationInfo;
        app_info.sType              = .APPLICATION_INFO;
        app_info.pApplicationName   = "Vulk";
        app_info.applicationVersion = VK_MAKE_VERSION(1, 2, 0);
        app_info.pEngineName        = "No Engine";
        app_info.engineVersion      = VK_MAKE_VERSION(1, 2, 0);
        app_info.apiVersion         = VK_API_VERSION_1_2;

        // Create Vulkan Instance
        create_info : VkInstanceCreateInfo;
        create_info.sType                   = .INSTANCE_CREATE_INFO;
        create_info.pApplicationInfo        = *app_info;

        #if !DEBUG {
            extensions: [2] *u8;
            extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
            // @ToDo: Non-Windows version
            extensions[1] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data;
        } else {
            #if OS == .WINDOWS {
                extensions: [3] *u8;
                extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
                extensions[1] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data;
                extensions[2] = VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data;
            } else {
                extensions: [0] *u8;
                // @ToDo: Non-Windows version
                #assert(false);
            }
        }

        create_info.enabledExtensionCount   = extensions.count;
        create_info.ppEnabledExtensionNames = extensions.data;

        #if DEBUG {
            debug_create_info := create_info;
            debug_create_info.enabledLayerCount = 1;
            debug_create_info.ppEnabledLayerNames = (*u8).["VK_LAYER_LUNARG_standard_validation"].data;

            result = vkCreateInstance(*debug_create_info, null, *instance);
            if result == .SUCCESS {
                vkCreateDebugReportCallbackEXT  : PFN_vkCreateDebugReportCallbackEXT = xx vkGetInstanceProcAddr(instance, "vkCreateDebugReportCallbackEXT");
                vkDestroyDebugReportCallbackEXT = xx vkGetInstanceProcAddr(instance, "vkDestroyDebugReportCallbackEXT");
                vkDebugReportMessageEXT         : PFN_vkDebugReportMessageEXT = xx vkGetInstanceProcAddr(instance, "vkDebugReportMessageEXT");

                if vkCreateDebugReportCallbackEXT {
                    debug_callback_create_info: VkDebugReportCallbackCreateInfoEXT;
                    debug_callback_create_info.flags |= .ERROR_BIT_EXT;
                    debug_callback_create_info.flags |= .WARNING_BIT_EXT;
                    debug_callback_create_info.pfnCallback = debug_callback;

                    vkCreateDebugReportCallbackEXT(instance, *debug_callback_create_info, null, *debug_callback_handle);
                }
            }
        }

        if result != .SUCCESS {
            result = vkCreateInstance(*create_info, null, *instance);
        }

        assert(result == .SUCCESS, "Vulkan Initialization failed.");
    }


    // Init Surface
    ////////////////////////////////////////////////////////////////////////////////
    {
        #if OS == .WINDOWS {
            my_hwnd := window;
            surfaceCreateInfo: VkWin32SurfaceCreateInfoKHR; 
            surfaceCreateInfo.sType     = .WIN32_SURFACE_CREATE_INFO_KHR;
            surfaceCreateInfo.hinstance = GetModuleHandleW(null);
            surfaceCreateInfo.hwnd      = my_hwnd;
            result := vkCreateWin32SurfaceKHR(instance, *surfaceCreateInfo, null, *surface);
            assert(result == .SUCCESS, "Surface creation failed.");
        } else {
            // @ToDo
            #assert(false);
        }
    }


    // Init Device
    ////////////////////////////////////////////////////////////////////////////////
    {
        // Picking physical device
        //
        MAX_DEVICE_COUNT :: 8;
        MAX_QUEUE_COUNT  :: 4;   // ATM there should be at most transfer, graphics, compute, graphics+compute families

        device_handles         : [MAX_DEVICE_COUNT] VkPhysicalDevice;
        queue_family_properties: [MAX_QUEUE_COUNT] VkQueueFamilyProperties;
        physical_device_count  : u32;

        vkEnumeratePhysicalDevices(instance, *physical_device_count, null);
        physical_device_count = min(physical_device_count, MAX_DEVICE_COUNT);
        vkEnumeratePhysicalDevices(instance, *physical_device_count, device_handles.data);

        print("Physical device count: %\n", physical_device_count);

        for i: 0..physical_device_count-1 {
            queue_family_count: u32 = 0;
            vkGetPhysicalDeviceQueueFamilyProperties(device_handles[i], *queue_family_count, null);
            queue_family_count = min(queue_family_count, MAX_QUEUE_COUNT);
            vkGetPhysicalDeviceQueueFamilyProperties(device_handles[i], *queue_family_count, queue_family_properties.data);

            print("Physical device % supports % queues families.\n", i, queue_family_count);

            for j: 0..queue_family_count-1 {
                supports_present := VK_FALSE;
                vkGetPhysicalDeviceSurfaceSupportKHR(device_handles[i], j, surface, *supports_present);

                print("Queue family properties: %.\n", queue_family_properties[j]);

                if supports_present && (queue_family_properties[j].queueFlags & .GRAPHICS_BIT) {
                    queue_family_index = j;
                    physical_device = device_handles[i];
                    print("Queue family % supports present and graphics.\n", j);
                    break;
                }
            }

            if (physical_device) {

                print_available_device_extensions();

                break;
            }
        }

        // Logical device
        //
        queue_create_info: VkDeviceQueueCreateInfo;
        queue_create_info.sType = .DEVICE_QUEUE_CREATE_INFO;
        queue_create_info.queueFamilyIndex = queue_family_index;
        queue_create_info.queueCount = 1;
        queue_create_info.pQueuePriorities = float.[1.0].data;

        device_create_info: VkDeviceCreateInfo;
        {
            using device_create_info;
            exexe: [1] *u8;
            exexe[0] = VK_KHR_SWAPCHAIN_EXTENSION_NAME.data;
            queueCreateInfoCount    = 1;
            pQueueCreateInfos       = *queue_create_info;
            enabledLayerCount       = 0;
            ppEnabledLayerNames     = null;

            enabledExtensionCount   = exexe.count;
            ppEnabledExtensionNames = exexe.data;
            pEnabledFeatures = null;
        }
        
        result := vkCreateDevice(physical_device, *device_create_info, null, *device);

        vkGetDeviceQueue(device, queue_family_index, queueIndex=0, *queue);

        assert(result == .SUCCESS, "Device initialization failed.");
    }


    // Init Swapchain
    ////////////////////////////////////////////////////////////////////////////////
    {
        PRESENT_MODE_MAILBOX_IMAGE_COUNT :u32: 3;
        PRESENT_MODE_DEFAULT_IMAGE_COUNT :u32: 2;

        // Use first available format
        formatCount : u32 = 1;
        vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, *formatCount, null); // suppress validation layer
        vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, *formatCount, *surfaceFormat);
        surfaceFormat.format = ifx surfaceFormat.format == .UNDEFINED then .B8G8R8A8_UNORM else surfaceFormat.format;

        presentModeCount : u32 = 0;
        vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, *presentModeCount, null);
        presentModes: [MAX_PRESENT_MODE_COUNT]VkPresentModeKHR;
        presentModeCount = min(presentModeCount, MAX_PRESENT_MODE_COUNT);
        vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, *presentModeCount, presentModes.data);

        presentMode : VkPresentModeKHR = .FIFO_KHR;   // always supported.
        for 0..presentModeCount-1 {
            if presentModes[it] == .MAILBOX_KHR {
                presentMode = .MAILBOX_KHR;
                break;
            }
        }
        
        swapchainImageCount = ifx presentMode == .MAILBOX_KHR  then PRESENT_MODE_MAILBOX_IMAGE_COUNT else  PRESENT_MODE_DEFAULT_IMAGE_COUNT;

        surfaceCapabilities: VkSurfaceCapabilitiesKHR;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, *surfaceCapabilities);

        swapchainExtent = surfaceCapabilities.currentExtent;
        if swapchainExtent.width == U32_MAX {
            swapchainExtent.width  = clamp(width, surfaceCapabilities.minImageExtent.width, surfaceCapabilities.maxImageExtent.width);
            swapchainExtent.height = clamp(height, surfaceCapabilities.minImageExtent.height, surfaceCapabilities.maxImageExtent.height);
        }

        swapChainCreateInfo: VkSwapchainCreateInfoKHR;
        the_surface := surface;  // No way yet to avoid importing this with 'using'. Should fix that!
        {
            swapChainCreateInfo.surface = the_surface;

            using swapChainCreateInfo;
            minImageCount               = swapchainImageCount;
            imageFormat                 = surfaceFormat.format;
            imageColorSpace             = surfaceFormat.colorSpace;
            imageExtent                 = swapchainExtent;
            imageArrayLayers            = 1; // 2 for stereo
            imageUsage                  |= .COLOR_ATTACHMENT_BIT;
            imageUsage                  |=  .TRANSFER_DST_BIT;
            imageSharingMode            = .EXCLUSIVE;
            preTransform                = surfaceCapabilities.currentTransform;
            compositeAlpha              = .OPAQUE_BIT_KHR;
            presentMode                 = presentMode;
            clipped                     = VK_TRUE;
        }
        
        result := vkCreateSwapchainKHR(device, *swapChainCreateInfo, null, *swapchain);
        assert(result == .SUCCESS, "Swapchain initialization failed.");

        vkGetSwapchainImagesKHR(device, swapchain, *swapchainImageCount, null);
        vkGetSwapchainImagesKHR(device, swapchain, *swapchainImageCount, swapchainImages.data);
    }


    // Init Render.
    ////////////////////////////////////////////////////////////////////////////////
    {
        commandPoolCreateInfo: VkCommandPoolCreateInfo;
        commandPoolCreateInfo.flags            = .RESET_COMMAND_BUFFER_BIT;
        commandPoolCreateInfo.queueFamilyIndex = queue_family_index;
        vkCreateCommandPool(device, *commandPoolCreateInfo, null, *commandPool);

        commandBufferAllocInfo: VkCommandBufferAllocateInfo;
        commandBufferAllocInfo.commandPool        = commandPool;
        commandBufferAllocInfo.level              = .PRIMARY;
        commandBufferAllocInfo.commandBufferCount = FRAME_COUNT;

        vkAllocateCommandBuffers(device, *commandBufferAllocInfo, commandBuffers.data);

        semaphoreCreateInfo: VkSemaphoreCreateInfo;
        vkCreateSemaphore(device, *semaphoreCreateInfo, null, *imageAvailableSemaphores[0]);
        vkCreateSemaphore(device, *semaphoreCreateInfo, null, *imageAvailableSemaphores[1]);
        vkCreateSemaphore(device, *semaphoreCreateInfo, null, *renderFinishedSemaphores[0]);
        vkCreateSemaphore(device, *semaphoreCreateInfo, null, *renderFinishedSemaphores[1]);

        fenceCreateInfo: VkFenceCreateInfo;
        fenceCreateInfo.flags = .SIGNALED_BIT;

        vkCreateFence(device, *fenceCreateInfo, null, *frameFences[0]);
        vkCreateFence(device, *fenceCreateInfo, null, *frameFences[1]);
    }
}

////////////////////////////////////////////////////////////////////////////////

deinit :: () {
    // Deinit Render
    {
        vkDeviceWaitIdle(device);
        vkDestroyFence(device, frameFences[0], null);
        vkDestroyFence(device, frameFences[1], null);
        vkDestroySemaphore(device, renderFinishedSemaphores[0], null);
        vkDestroySemaphore(device, renderFinishedSemaphores[1], null);
        vkDestroySemaphore(device, imageAvailableSemaphores[0], null);
        vkDestroySemaphore(device, imageAvailableSemaphores[1], null);
        vkDestroyCommandPool(device, commandPool, null);
    }

    // Deinit Swapchain
    {
        vkDestroySwapchainKHR(device, swapchain, null);
    }

    // Deinit Device
    {
        vkDestroyDevice(device, null);
    }

    // Deinit Surface
    {
        vkDestroySurfaceKHR(instance, surface, null);
    }

    // Deinit Vulkan
    {
        #if DEBUG {
            if vkDestroyDebugReportCallbackEXT && debug_callback_handle {
                vkDestroyDebugReportCallbackEXT(instance, debug_callback_handle, null);
            }
        }
        vkDestroyInstance(instance, null);
    }
}
