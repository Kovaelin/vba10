
#pragma once

#ifndef NO_XBOX

#include "Input.h"
#include "CXBOXController.h"
#include "EmulatorInput.h"

namespace VBA10
{
	class ControllerInput: public EmulatorInput
	{
	public:
		ControllerInput(int index);
		~ControllerInput(void);

		const ControllerState *GetControllerState(void);
		void Update(void);

	private:
		ControllerState state;
		CXBOXController *xboxPad;

		void GetMapping(int pressedButton, bool* a, bool* b, bool* l, bool* r, bool* turbo);
	};
}
#endif