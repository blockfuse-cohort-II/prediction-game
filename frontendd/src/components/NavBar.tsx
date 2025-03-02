const NavBar = () => {
  return (
    <div className="container flex items-center justify-between md:mx-auto my-6 bg-[#2463FF]/40 py-2 px-6 rounded-full">
      <div className="rounded-[2.5rem]  py-3 flex items-center gap-2 text-xl">
        <img src="/images/trophy-svgrepo-com.svg" className="h-5" />
        <p>LeaderBoard</p>
      </div>

      <div className="flex text-lg">
        <p>@Username</p>

        
      </div>
    </div>
  );
};

export default NavBar;
