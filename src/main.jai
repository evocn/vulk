// Vulk
// Main
// February 2024

DEBUG :: true;

////////////////////////////////////////////////////////////////////////////////

width                 : u32 = 640;
height                : u32 = 480;
window                : Window_Type;

instance              : VkInstance;
debug_callback_handle : VkDebugReportCallbackEXT;

surface               : VkSurfaceKHR;

physical_device       : VkPhysicalDevice;
queue_family_index    : u32;
device                : VkDevice;
queue                 : VkQueue;


// Swapchain Variables
MAX_PRESENT_MODE_COUNT :: 6; // At the moment in spec
MAX_SWAPCHAIN_IMAGES   :: 3;
swapchain: VkSwapchainKHR;
swapchainImageCount: u32;
swapchainImages: [MAX_SWAPCHAIN_IMAGES] VkImage;
swapchainExtent: VkExtent2D;
surfaceFormat  : VkSurfaceFormatKHR;


// Render Variables
FRAME_COUNT :: 2;
frame_index := 0;
commandPool   : VkCommandPool;
commandBuffers: [FRAME_COUNT]VkCommandBuffer;
frameFences   : [FRAME_COUNT]VkFence; // Create with VK_FENCE_CREATE_SIGNALED_BIT.
imageAvailableSemaphores: [FRAME_COUNT]VkSemaphore;
renderFinishedSemaphores: [FRAME_COUNT]VkSemaphore;


////////////////////////////////////////////////////////////////////////////////

main :: () {
    // Create window
    window = create_window(xx width, xx height, "Vulk");

    init();
  
    running := true;
    while running {
        update_window_events();

        for event: events_this_frame {
            if event.type == .QUIT then running = false;
            if event.type == .KEYBOARD then {
                using event;
                if !key_pressed && key_code == Key_Code.ESCAPE {
                    running = false;
                }
            }
        }

        draw_frame();
    }

    deinit();
}

////////////////////////////////////////////////////////////////////////////////

#load "util.jai";
#load "init.jai";
#load "draw.jai";

////////////////////////////////////////////////////////////////////////////////

#import "Basic";
#import "String";
#import "Math";
#import "Vulkan";

#import "Window_Creation";
#import "Input";
#if OS ==.WINDOWS {
    #import "Windows";
}
