;;;; device-service-protocols.lisp --- IGraphicsDeviceManager and
;;;; IGraphicsDeviceService.
;;;;
;;;; Two CLR interfaces, projected the way this binding projects an interface:
;;;; as generic functions plus a declared service-type name, rather than as a
;;;; class. `GraphicsDeviceManager' implements both -- the pinned assembly says
;;;; so in its own class header:
;;;;
;;;;     .class public auto ansi beforefieldinit GraphicsDeviceManager
;;;;            extends System.Object
;;;;            implements Graphics.IGraphicsDeviceService,
;;;;                       System.IDisposable,
;;;;                       IGraphicsDeviceManager
;;;;
;;;; -- which is also why these two types are in this closure at all. They were
;;;; already reachable from the *current* selection: `GraphicsDeviceManager' has
;;;; been selected since Foundation 1 and names them in its `interfaces', so the
;;;; dependency closure over the pinned contract has had a hole in it that this
;;;; closure fills. The planning pass counted `FrameworkDispatcher' here instead;
;;;; the contract disagrees, and the contract is the authority.
;;;;
;;;; **There is no second object and no duplicate event state.** Both interfaces
;;;; are answered by the manager itself, so retrieving it through either service
;;;; key and calling through the protocol reaches the same object, the same
;;;; handler lists and the same native registrations as the concrete API does.
;;;; That is what `IGraphicsDeviceService''s four events being "also the
;;;; canonical graphics-device-service events" means in CNA's own header, and a
;;;; wrapper here would have quietly made it false.

(in-package #:microsoft.xna.framework)

;;; --- IGraphicsDeviceManager -------------------------------------------------

(define-service-protocol igraphics-device-manager)

(setf (documentation 'igraphics-device-manager 'variable)
      "Microsoft.Xna.Framework.IGraphicsDeviceManager, as a service type designator.

Not a class: this binding projects a CLR interface as generic functions plus a
name that can key a service. Use it as the key:

    (get-service (services game) 'igraphics-device-manager)

The three members are CREATE-DEVICE, BEGIN-DRAW-DEVICE and END-DRAW-DEVICE, and
the interface has exactly those three -- verified against the pinned assembly's
interface declaration rather than assumed from CNA's route list.")

(defgeneric create-device (manager)
  (:documentation
   "IGraphicsDeviceManager.CreateDevice(): create or re-create the managed device.

    (create-device (get-service (services game) 'igraphics-device-manager))

XNA's game calls this while initialising, so a program normally never does. CNA
says the same about its route and adds what is different here: \"in this runtime
the game already owns its device, so this re-applies the configuration rather
than allocating a new device\".

**This is one of the two ways to reach the PreparingDeviceSettings event for
real.** CNA's `create_device' runs device preparation, which computes the
proposal and raises the event before anything is created -- so a handler
registered with ADD-PREPARING-DEVICE-SETTINGS-HANDLER is called from inside this
call, and what it writes is what the device is configured from.

Answers no values, as the original returns void."))

(defgeneric begin-draw-device (manager)
  (:documentation
   "IGraphicsDeviceManager.BeginDraw(): whether the frame may draw.

Answers true when drawing may proceed. Named BEGIN-DRAW-DEVICE rather than
BEGIN-DRAW because `Game.BeginDraw' is a different member on a different type and
already owns that name in this package -- the same collision XNA resolves by
having two types."))

(defgeneric end-draw-device (manager)
  (:documentation
   "IGraphicsDeviceManager.EndDraw(): present the frame the device drew.

Named for the reason BEGIN-DRAW-DEVICE is. Answers no values, as the original
returns void."))

;;; --- IGraphicsDeviceService -------------------------------------------------

(define-service-protocol igraphics-device-service)

(setf (documentation 'igraphics-device-service 'variable)
      "Microsoft.Xna.Framework.Graphics.IGraphicsDeviceService, as a service type
designator.

    (get-service (services game) 'igraphics-device-service)

Five members: the `GraphicsDevice' property and the four device events. **All
five are the ones GRAPHICS-DEVICE-MANAGER already exposes**, and deliberately so
-- GRAPHICS-DEVICE answers the property, and ADD-DEVICE-CREATED-HANDLER and its
three siblings are the events. Subscribing through this service key and
subscribing through the concrete manager reach one handler list and one native
registration, because they reach one object.

This is the key a `ContentManager' resolves a graphics device through: XNA's
content readers call `contentManager.ServiceProvider.GetService(typeof(
IGraphicsDeviceService))` and then `.GraphicsDevice` on what comes back.")
