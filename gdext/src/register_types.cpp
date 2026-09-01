#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "far_mesher.h"
#include "height_tiles.h"

using namespace godot;

void initialize_kubik_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(KubikFarMesher);
	// DISTANCE V5 STAGE 4. The height map's tile builder - world truth, hence
	// its own class rather than more methods on the look-only far mesher.
	GDREGISTER_CLASS(KubikHeightTiles);
}

void uninitialize_kubik_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT kubik_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(
			p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_kubik_module);
	init_obj.register_terminator(uninitialize_kubik_module);
	init_obj.set_minimum_library_initialization_level(
			MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
